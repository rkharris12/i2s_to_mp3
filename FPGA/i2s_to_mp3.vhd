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
        I2S_LRCK : in  std_logic; -- GPIO 26 on ESP
        I2S_BCK  : in  std_logic; -- GPIO 27 on ESP
        I2S_DATA : in  std_logic; -- GPIO 25 on ESP
        SPARE_IN : in  std_logic; -- GPIO 33 on ESP
        ESP_EN   : out std_logic; -- EN
        ESP_3V3  : in  std_logic  -- 3V3
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
            I2S_LRCK        : in  std_logic;
            I2S_BCK         : in  std_logic;
            I2S_DATA        : in  std_logic;
            ARST_I2S_N      : in  std_logic;
            CLK_AVL         : in  std_logic;
            ARST_AVL_N      : in  std_logic;
            START           : in  std_logic;
            DONE            : out std_logic;
            SAMPLE_DATA_ACK : in std_logic;
            SAMPLE_DATA     : out std_logic_vector(31 downto 0);
            LRCK_CNT        : out std_logic_vector(31 downto 0);
            BCK_CNT         : out std_logic_vector(31 downto 0)
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

    constant C_VERSION             : std_logic_vector(31 downto 0) := x"00000011";

    signal clk_avalon              : std_logic;
    signal arst_avalon_n           : std_logic;

    signal arst_i2s_n              : std_logic;

    signal m_avalon_address        : std_logic_vector(31 downto 0);
    signal m_avalon_byteenable     : std_logic_vector(3 downto 0);
    signal m_avalon_read           : std_logic;
    signal m_avalon_readdata       : std_logic_vector(31 downto 0);
    signal m_avalon_readdatavalid  : std_logic;
    signal m_avalon_waitrequest    : std_logic;
    signal m_avalon_write          : std_logic;
    signal m_avalon_writedata      : std_logic_vector(31 downto 0);
    signal s_avalon_address        : std_logic_vector(31 downto 0);
    signal s_avalon_burstcount     : std_logic_vector(10 downto 0);
    signal s_avalon_read           : std_logic;
    signal s_avalon_readdata       : std_logic_vector(63 downto 0);
    signal s_avalon_readdatavalid  : std_logic;
    signal s_avalon_waitrequest    : std_logic;
    signal s_avalon_write          : std_logic;
    signal s_avalon_writedata      : std_logic_vector(63 downto 0);

    type state_type                is (E_IDLE, E_DELAY, E_WRITE, E_DONE);
    signal state                   : state_type;
    
    signal address_bank            : std_logic_vector(7 downto 0);
    signal address_offset          : std_logic_vector(7 downto 0);

    signal s_avalon_waitrequest_d1 : std_logic;
    signal avalon_word_cnt         : unsigned(15 downto 0);
    signal transfer_done           : std_logic;
    signal transfer_done_latched   : std_logic;
    signal sample_data_ack         : std_logic;
    signal sample_data             : std_logic_vector(31 downto 0);
    signal sample_data_reg         : std_logic_vector(31 downto 0);

    signal capture_base_address    : std_logic_vector(31 downto 0);
    signal start_i2s_avl           : std_logic;

    signal start_i2s               : std_logic;
    signal lrck_cnt                : std_logic_vector(31 downto 0);
    signal bck_cnt                 : std_logic_vector(31 downto 0);
    signal capture_done            : std_logic;

    -- debug
    component ila_i2s is
        Port ( 
            clk : in STD_LOGIC;
            probe0 : in STD_LOGIC_VECTOR ( 31 downto 0 );
            probe1 : in STD_LOGIC_VECTOR ( 31 downto 0 );
            probe2 : in STD_LOGIC_VECTOR ( 0 to 0 );
            probe3 : in STD_LOGIC_VECTOR ( 0 to 0 );
            probe4 : in STD_LOGIC_VECTOR ( 31 downto 0 );
            probe5 : in STD_LOGIC_VECTOR ( 31 downto 0 );
            probe6 : in STD_LOGIC_VECTOR ( 0 to 0 )
        );
    end component;

    attribute syn_black_box : boolean;
    attribute syn_black_box of ila_i2s : component is true;

    attribute syn_noprune : boolean;
    attribute syn_noprune of ila_i2s : component is true;

    attribute syn_keep : boolean;
    attribute syn_keep of sample_data : signal is true;
    attribute syn_keep of sample_data_reg : signal is true;
    attribute syn_keep of sample_data_ack : signal is true;
    attribute syn_keep of s_avalon_write : signal is true;
    attribute syn_keep of s_avalon_writedata : signal is true;
    attribute syn_keep of s_avalon_address : signal is true;
    attribute syn_keep of s_avalon_waitrequest : signal is true;

begin

    -- debug
    u_ila_i2s : ila_i2s
        Port map ( 
          clk       => clk_avalon,
          probe0    => sample_data,
          probe1    => sample_data_reg,
          probe2(0) => sample_data_ack,
          probe3(0) => s_avalon_write,
          probe4    => s_avalon_address,
          probe5    => s_avalon_writedata(31 downto 0),
          probe6(0) => s_avalon_waitrequest
        );

    -- ESP power and enable
    ESP_EN  <= '1';
    --ESP_3V3 <= '1';

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
    s_avalon_read <= '0';

    -- write the captured audio data to the processor memory
    process(clk_avalon, arst_avalon_n) begin
        if (arst_avalon_n = '0') then
            state                   <= E_IDLE;
            transfer_done           <= '0';
            avalon_word_cnt         <= (others => '0');
            sample_data_reg         <= (others => '0');
            s_avalon_waitrequest_d1 <= '0';
            s_avalon_write          <= '0';
            s_avalon_writedata      <= (others => '0');
            s_avalon_address        <= (others => '0');
            s_avalon_burstcount     <= (others => '0');
        elsif rising_edge(clk_avalon) then
            s_avalon_waitrequest_d1 <= s_avalon_waitrequest;

            transfer_done <= '0';

            if ((not (s_avalon_waitrequest = '1' and s_avalon_waitrequest_d1 = '1')) or state = E_DELAY) then
                sample_data_reg <= sample_data;
            end if;

            case (state) is
                when E_IDLE =>
                    if (capture_done = '1') then
                        state               <= E_DELAY;
                        s_avalon_address    <= capture_base_address;
                        s_avalon_burstcount <= std_logic_vector(to_unsigned(1, s_avalon_burstcount'length)); -- no burst writes
                    end if;

                when E_DELAY =>
                    state              <= E_WRITE;
                    s_avalon_write     <= '1';
                    s_avalon_writedata <= x"1234567812345678";--sample_data;

                when E_WRITE =>
                    if (s_avalon_waitrequest = '0') then
                        if (s_avalon_waitrequest_d1 = '1') then
                            s_avalon_writedata <= x"1234567812345678";--sample_data_reg;
                        else
                            s_avalon_writedata <= x"1234567812345678";--sample_data;
                        end if;
                        s_avalon_address <= std_logic_vector(unsigned(s_avalon_address) + 8);
                        avalon_word_cnt  <= avalon_word_cnt + 1;
                        if (avalon_word_cnt = 65535) then
                            state           <= E_DONE;
                            avalon_word_cnt <= (others => '0');
                            s_avalon_write  <= '0';
                        end if;
                    end if;
                
                when E_DONE =>
                    state         <= E_IDLE;
                    transfer_done <= '1';
                    
                when others =>
                    null;
            end case;
        end if;
    end process;

    -- ack data from i2s sample buffer
    sample_data_ack <= '1' when ((state = E_IDLE and capture_done = '1') or (state = E_WRITE and s_avalon_waitrequest = '0')) else '0';

    -- register interface
    m_avalon_waitrequest <= '0'; -- always ready
  
    -- decode register address
    address_bank   <= m_avalon_address(15 downto 8);
    address_offset <= m_avalon_address(7 downto 0);

    process(clk_avalon, arst_avalon_n) begin
        if (arst_avalon_n = '0') then
            m_avalon_readdata      <= (others => '0');
            m_avalon_readdatavalid <= '0';
            start_i2s_avl          <= '0';
            capture_base_address   <= (others => '0');
            transfer_done_latched  <= '0';
        elsif rising_edge(clk_avalon) then
            m_avalon_readdata      <= (others => '0');
            m_avalon_readdatavalid <= '0';

            start_i2s_avl <= '0';

            if (transfer_done = '1') then
                transfer_done_latched <= '1';
            end if;

            -- read
            if (m_avalon_read = '1') then
                m_avalon_readdatavalid <= '1';
                if (to_integer(unsigned(address_bank)) = 0) then
                    case to_integer(unsigned(address_offset)) is
                        when 0 =>
                            m_avalon_readdata <= C_VERSION;
                        when 2 =>
                            m_avalon_readdata <= capture_base_address;
                        when 3 =>
                            m_avalon_readdata <= (0 => transfer_done_latched, others => '0');
                            if (transfer_done_latched = '1') then -- clear latched if processor reads a 1
                                transfer_done_latched <= '0';
                            end if;
                        when 4 =>
                            m_avalon_readdata <= lrck_cnt;
                        when 5 =>
                            m_avalon_readdata <= bck_cnt;
                        when others =>
                            null;
                    end case;
                end if;
            -- write
            elsif (m_avalon_write = '1') then
                if (to_integer(unsigned(address_bank)) = 0) then
                    case to_integer(unsigned(address_offset)) is
                        when 1 =>
                            start_i2s_avl <= m_avalon_writedata(0);
                        when 2 =>
                            capture_base_address <= m_avalon_writedata;
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
            DIN        => start_i2s_avl,
            DOUT       => start_i2s);

    -- I2S wrapper
    u_i2s : i2s
        port map (
            I2S_LRCK        => I2S_LRCK,
            I2S_BCK         => I2S_BCK,
            I2S_DATA        => I2S_DATA,
            ARST_I2S_N      => arst_i2s_n,
            CLK_AVL         => clk_avalon,
            ARST_AVL_N      => arst_avalon_n,
            START           => start_i2s,
            DONE            => capture_done,
            SAMPLE_DATA_ACK => sample_data_ack,
            SAMPLE_DATA     => sample_data,
            LRCK_CNT        => lrck_cnt,
            BCK_CNT         => bck_cnt);

end rtl;
