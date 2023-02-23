----------------------------------------------------------------------------------
-- Richie Harris
-- rkharris12@gmail.com
-- 2/22/2023
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity i2s_to_mp3 is
    port (
        I2S_LRCK : in std_logic; -- GPIO 22 on ESP
        I2S_BCK  : in std_logic; -- GPIO 21 on ESP
        I2S_DATA : in std_logic -- GPIO 23 on ESP
    );
end i2s_to_mp3;

architecture rtl of i2s_to_mp3 is

    component soc_wrapper is
        port (
            ARST_AVL_N             : out std_logic_vector(0 to 0);
            CLK_AVL                : out std_logic;
            M_AVALON_address       : out std_logic_vector(31 downto 0);
            M_AVALON_byteenable    : out std_logic_vector(3 downto 0);
            M_AVALON_read          : out std_logic;
            M_AVALON_readdata      : in  std_logic_vector(31 downto 0);
            M_AVALON_readdatavalid : in  std_logic;
            M_AVALON_waitrequest   : in  std_logic;
            M_AVALON_write         : out std_logic;
            M_AVALON_writedata     : out std_logic_vector(31 downto 0);
            S_AVALON_address       : in  std_logic_vector(31 downto 0);
            S_AVALON_burstcount    : in  std_logic_vector(10 downto 0);
            S_AVALON_read          : in  std_logic;
            S_AVALON_readdata      : out std_logic_vector(63 downto 0);
            S_AVALON_readdatavalid : out std_logic;
            S_AVALON_waitrequest   : out std_logic;
            S_AVALON_write         : in  std_logic;
            S_AVALON_writedata     : in  std_logic_vector(63 downto 0)
        );
    end component;

    component i2s is
        port (
            I2S_LRCK   : in  std_logic;
            I2S_BCK    : in  std_logic;
            I2S_DATA   : in  std_logic;
            ARST_I2S_N : in  std_logic;
            SRST_I2S   : in  std_logic;
            CLK_AVL    : in  std_logic;
            ARST_AVL_N : in  std_logic;
            LRCK_CNT   : out std_logic_vector(31 downto 0);
            BCK_CNT    : out std_logic_vector(31 downto 0)
        );
    end component;

    component pulse_cdc is
        port (
            CLK_IN     : in  std_logic;
            ARST_IN_N  : in  std_logic;
            CLK_OUT    : in  std_logic;
            ARST_OUT_N : in  std_logic;
            DIN        : in  std_logic;
            DOUT       : out std_logic
        );
    end component;

    component arst_n_sync_release is
        port (
            CLK        : in  std_logic;
            ARST_IN_N  : in  std_logic;
            ARST_OUT_N : out std_logic
        );
    end component;

    constant C_VERSION            : std_logic_vector(31 downto 0) := x"00000010";

    signal clk_avalon             : std_logic;
    signal arst_avalon_n          : std_logic;

    signal arst_i2s_n             : std_logic;

    signal m_avalon_address       : std_logic_vector(31 downto 0);
    signal m_avalon_byteenable    : std_logic_vector(3 downto 0);
    signal m_avalon_read          : std_logic;
    signal m_avalon_readdata      : std_logic_vector(31 downto 0);
    signal m_avalon_readdatavalid : std_logic;
    signal m_avalon_waitrequest   : std_logic;
    signal m_avalon_write         : std_logic;
    signal m_avalon_writedata     : std_logic_vector(31 downto 0);
    signal s_avalon_address       : std_logic_vector(31 downto 0);
    signal s_avalon_burstcount    : std_logic_vector(10 downto 0);
    signal s_avalon_read          : std_logic;
    signal s_avalon_readdata      : std_logic_vector(63 downto 0);
    signal s_avalon_readdatavalid : std_logic;
    signal s_avalon_waitrequest   : std_logic;
    signal s_avalon_write         : std_logic;
    signal s_avalon_writedata     : std_logic_vector(63 downto 0);
    
    signal address_bank           : std_logic_vector(7 downto 0);
    signal address_offset         : std_logic_vector(7 downto 0);

    signal srst_i2s_avl           : std_logic;
    signal srst_i2s               : std_logic;
    signal lrck_cnt               : std_logic_vector(31 downto 0);
    signal bck_cnt                : std_logic_vector(31 downto 0);

begin

    -- instantiate processor interface
    u_soc_wrapper : soc_wrapper
        port map (
            ARST_AVL_N(0)          => arst_avalon_n,
            CLK_AVL                => clk_avalon,
            M_AVALON_address       => m_avalon_address,
            M_AVALON_byteenable    => m_avalon_byteenable,
            M_AVALON_read          => m_avalon_read,
            M_AVALON_readdata      => m_avalon_readdata,
            M_AVALON_readdatavalid => m_avalon_readdatavalid,
            M_AVALON_waitrequest   => m_avalon_waitrequest,
            M_AVALON_write         => m_avalon_write,
            M_AVALON_writedata     => m_avalon_writedata,
            S_AVALON_address       => s_avalon_address,
            S_AVALON_burstcount    => s_avalon_burstcount,
            S_AVALON_read          => s_avalon_read,
            S_AVALON_readdata      => s_avalon_readdata,
            S_AVALON_readdatavalid => s_avalon_readdatavalid,
            S_AVALON_waitrequest   => s_avalon_waitrequest,
            S_AVALON_write         => s_avalon_write,
            S_AVALON_writedata     => s_avalon_writedata);

    -- memory interface
    s_avalon_address    <= (others => '0');
    s_avalon_burstcount <= (others => '0');
    s_avalon_read       <= '0';
    s_avalon_write      <= '0';
    s_avalon_writedata  <= (others => '0');

    -- register interface
    m_avalon_waitrequest <= '0'; -- always ready
  
    -- decode register address
    address_bank   <= m_avalon_address(15 downto 8);
    address_offset <= m_avalon_address(7 downto 0);

    process(clk_avalon, arst_avalon_n) begin
        if (arst_avalon_n = '0') then
            m_avalon_readdata      <= (others => '0');
            m_avalon_readdatavalid <= '0';
            srst_i2s_avl           <= '0';
        elsif rising_edge(clk_avalon) then
            m_avalon_readdata      <= (others => '0');
            m_avalon_readdatavalid <= '0';

            srst_i2s_avl <= '0';

            -- read
            if (m_avalon_read = '1') then
                m_avalon_readdatavalid <= '1';
                if (to_integer(unsigned(address_bank)) = 0) then
                    case to_integer(unsigned(address_offset)) is
                        when 0 =>
                            m_avalon_readdata <= C_VERSION;
                        when 2 =>
                            m_avalon_readata <= lrck_cnt;
                        when 3 =>
                            m_avalon_readata <= bck_cnt;
                        when others =>
                            null;
                    end case;
                end if;
            -- write
            elsif (m_avalon_write = '1') then
                if (to_integer(unsigned(address_bank)) = 0) then
                    case to_integer(unsigned(address_offset)) is
                        when 1 =>
                            srst_i2s_avl <= m_avalon_writedata(0);
                        when others =>
                            null;
                    end case;
                end if;
            end if;
        end if;
    end process;

    -- cdc resets to i2s clock
    i2s_arst_n_sync_release : arst_n_sync_release
        port map (
            CLK        => I2S_BCK,
            ARST_IN_N  => arst_avalon_n,
            ARST_OUT_N => arst_i2s_n);

    i2s_srst_resync : pulse_cdc
        port map (
            CLK_IN     => clk_avalon,
            ARST_IN_N  => arst_avalon_n,
            CLK_OUT    => I2S_BCK,
            ARST_OUT_N => arst_i2s_n,
            DIN        => srst_i2s_avl,
            DOUT       => srst_i2s);

    -- I2S wrapper
    u_i2s : i2s
        port map (
            I2S_LRCK   => I2S_LRCK,
            I2S_BCK    => I2S_BCK,
            I2S_DATA   => I2S_DATA,
            ARST_I2S_N => arst_i2s_n,
            SRST_I2S   => srst_i2s,
            CLK_AVL    => clk_avalon,
            ARST_AVL_N => arst_avalon_n,
            LRCK_CNT   => lrck_cnt,
            BCK_CNT    => bck_cnt);

end rtl;