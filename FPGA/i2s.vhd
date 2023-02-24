----------------------------------------------------------------------------------
-- Richie Harris
-- rkharris12@gmail.com
-- 2/22/2023
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity i2s is
    port (
        I2S_LRCK        : in  std_logic;
        I2S_BCK         : in  std_logic;
        I2S_DATA        : in  std_logic;
        ARST_I2S_N      : in  std_logic;
        SRST_I2S        : in  std_logic;
        CLK_AVL         : in  std_logic;
        ARST_AVL_N      : in  std_logic;
        DONE            : out std_logic;
        SAMPLE_DATA_ACK : in std_logic;
        SAMPLE_DATA     : out std_logic_vector(31 downto 0);
        LRCK_CNT        : out std_logic_vector(31 downto 0);
        BCK_CNT         : out std_logic_vector(31 downto 0)
    );
end i2s;

architecture rtl of i2s is

    component data_cdc is
        generic (
            G_DATA_BITS : integer
        );
        port (
            CLK_IN     : in  std_logic;
            ARST_IN_N  : in  std_logic;
            CLK_OUT    : in  std_logic;
            ARST_OUT_N : in  std_logic;
            DIN        : in  std_logic_vector(G_DATA_BITS-1 downto 0);
            DIN_EN     : in  std_logic;
            DOUT       : out std_logic_vector(G_DATA_BITS-1 downto 0);
            DOUT_EN    : out std_logic
        );
    end component;

    component sample_mem is
        port ( 
            clka  : in  std_logic;
            ena   : in  std_logic;
            wea   : in  std_logic_vector(0 to 0);
            addra : in  std_logic_vector(15 downto 0);
            dina  : in  std_logic_vector(31 downto 0);
            clkb  : in  std_logic;
            enb   : in  std_logic;
            addrb : in  std_logic_vector(15 downto 0);
            doutb : out std_logic_vector(31 downto 0)
        );
    end component;

    signal i2s_lrck_d1      : std_logic;
    signal i2s_lrck_left    : std_logic;
    signal i2s_lrck_toggle  : std_logic;
    signal i2s_shift_cnt    : unsigned(4 downto 0);
    type state_type         is (E_IDLE, E_CAPTURE, E_DONE);
    signal state            : state_type;
    signal sample_mem_we    : std_logic;
    signal sample_mem_waddr : unsigned(15 downto 0);
    signal sample_mem_data  : std_logic_vector(31 downto 0);
    signal sample_mem_raddr : unsigned(15 downto 0);
    signal done_i           : std_logic;
    signal done_sr          : std_logic_vector(1 downto 0);

    signal lrck_cnt_i2s     : unsigned(31 downto 0);
    signal bck_cnt_i2s      : unsigned(31 downto 0);
    signal bck_cnt_cdc_en   : std_logic;
    signal lrck_cnt_cdc_en  : std_logic;

begin

    -- detect left/right channel change
    process(I2S_BCK) begin
        if rising_edge(I2S_BCK) then
            i2s_lrck_d1 <= I2S_LRCK;
        end if;
    end process;

    i2s_lrck_toggle <= I2S_LRCK xor i2s_lrck_d1;
    i2s_lrck_left   <= '1' when (I2S_LRCK = '0' and i2s_lrck_d1 = '1') else '0';

    -- capture audio samples
    process(I2S_BCK, ARST_I2S_N) begin
        if (ARST_I2S_N = '0') then
            state            <= E_IDLE;
            i2s_shift_cnt    <= (others => '0');
            done_i           <= '0';
            sample_mem_we    <= '0';
            sample_mem_waddr <= (others => '0');
            sample_mem_data  <= (others => '0');
        elsif rising_edge(I2S_BCK) then
            if (SRST_I2S = '1') then
                state            <= E_IDLE;
                i2s_shift_cnt    <= (others => '0');
                done_i           <= '0';
                sample_mem_we    <= '0';
                sample_mem_waddr <= (others => '0');
                sample_mem_data  <= (others => '0');
            else
                sample_mem_we <= '0';

                case (state) is
                    when E_IDLE =>
                        if (i2s_lrck_left = '1') then
                            state           <= E_CAPTURE;
                            sample_mem_data <= I2S_DATA & sample_mem_data(30 downto 0);
                            i2s_shift_cnt   <= i2s_shift_cnt + 1;
                        end if;

                    when E_CAPTURE =>
                        sample_mem_data <= I2S_DATA & sample_mem_data(30 downto 0);
                        i2s_shift_cnt   <= i2s_shift_cnt + 1;
                        if (i2s_shift_cnt = 31) then
                            sample_mem_we <= '1';
                            sample_mem_waddr <= sample_mem_waddr + 1;
                            if (sample_mem_waddr = 65535) then
                                state <= E_DONE;
                            end if;
                        end if;

                    when E_DONE =>
                        done_i <= '1';

                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process;

    -- block RAM to store audio samples
    u_sample_mem : sample_mem
        port map ( 
            clka   => I2S_BCK,
            ena    => '1',
            wea(0) => sample_mem_we,
            addra  => std_logic_vector(sample_mem_waddr),
            dina   => sample_mem_data,
            clkb   => CLK_AVL,
            enb    => '1',
            addrb  => std_logic_vector(sample_mem_raddr),
            doutb  => SAMPLE_DATA);

    -- transfer captured audio data
    process(CLK_AVL, ARST_AVL_N) begin
        if (ARST_AVL_N = '0') then
            sample_mem_raddr <= (others => '0');
        elsif rising_edge(CLK_AVL) then
            if (SAMPLE_DATA_ACK = '1') then
                sample_mem_raddr <= sample_mem_raddr + 1;
            end if;
        end if;
    end process;
    
    -- debug counters
    process(I2S_BCK, ARST_I2S_N) begin
        if (ARST_I2S_N = '0') then
            bck_cnt_cdc_en  <= '0';
            lrck_cnt_cdc_en <= '0';
            lrck_cnt_i2s    <= (others => '0');
            bck_cnt_i2s     <= (others => '0');
        elsif rising_edge(I2S_BCK) then
            bck_cnt_cdc_en  <= '0';
            lrck_cnt_cdc_en <= '0';

            bck_cnt_i2s <= bck_cnt_i2s + 1;
            if (bck_cnt_i2s(3 downto 0) = 0) then
                bck_cnt_cdc_en <= '1';
            end if;

            if (i2s_lrck_toggle = '1') then
                lrck_cnt_i2s    <= lrck_cnt_i2s + 1;
                lrck_cnt_cdc_en <= '1';
            end if;
        end if;
    end process;

    -- resync signals to CLK_AVL
    process(CLK_AVL, ARST_AVL_N) begin
        if (ARST_AVL_N = '0') then
            done_sr <= (others => '0');
        elsif rising_edge(CLK_AVL) then
            done_sr <= done_sr(done_sr'high-1 downto 0) & done_i;
        end if;
    end process;
    DONE <= done_sr(done_sr'high);

    bck_cnt_cdc : data_cdc
        generic map (
            G_DATA_BITS => 32)
        port map (
            CLK_IN     => I2S_BCK,
            ARST_IN_N  => ARST_I2S_N,
            CLK_OUT    => CLK_AVL,
            ARST_OUT_N => ARST_AVL_N,
            DIN        => std_logic_vector(bck_cnt_i2s),
            DIN_EN     => bck_cnt_cdc_en,
            DOUT       => BCK_CNT,
            DOUT_EN    => open);

    lrck_cnt_cdc : data_cdc
        generic map (
            G_DATA_BITS => 32)
        port map (
            CLK_IN     => I2S_BCK,
            ARST_IN_N  => ARST_I2S_N,
            CLK_OUT    => CLK_AVL,
            ARST_OUT_N => ARST_AVL_N,
            DIN        => std_logic_vector(lrck_cnt_i2s),
            DIN_EN     => lrck_cnt_cdc_en,
            DOUT       => LRCK_CNT,
            DOUT_EN    => open);

end rtl;
