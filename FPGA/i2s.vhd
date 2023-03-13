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
        I2S_LRCK    : in  std_logic;
        I2S_BCK     : in  std_logic;
        I2S_DATA    : in  std_logic;
        ARST_I2S_N  : in  std_logic;
        CLK_AVL     : in  std_logic;
        ARST_AVL_N  : in  std_logic;
        SRST_I2S    : in  std_logic;
        CONFIG      : in  std_logic_vector(1 downto 0);
        SAMPLE_EN   : out std_logic;
        SAMPLE_DATA : out std_logic_vector(31 downto 0);
        LRCK_CNT    : out std_logic_vector(31 downto 0);
        BCK_CNT     : out std_logic_vector(31 downto 0)
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

    signal i2s_lrck_d1     : std_logic;
    signal i2s_lrck_left   : std_logic;
    signal i2s_lrck_toggle : std_logic;
    signal i2s_shift_cnt   : unsigned(4 downto 0);
    type state_type        is (E_RESET, E_CAPTURE);
    signal state           : state_type;
    signal sample_data_i2s : std_logic_vector(31 downto 0); -- left is lsb, right is msb
    signal sample_en_i2s   : std_logic;

    signal lrck_cnt_i2s    : unsigned(31 downto 0);
    signal bck_cnt_i2s     : unsigned(31 downto 0);
    signal bck_cnt_cdc_en  : std_logic;
    signal lrck_cnt_cdc_en : std_logic;

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
            state           <= E_RESET;
            i2s_shift_cnt   <= (others => '0');
            sample_en_i2s   <= '0';
            sample_data_i2s <= (others => '0');
        elsif rising_edge(I2S_BCK) then
            if (SRST_I2S = '1') then
                state           <= E_RESET;
                i2s_shift_cnt   <= (others => '0');
                sample_en_i2s   <= '0';
                sample_data_i2s <= (others => '0');
            else
                sample_en_i2s <= '0';

                case (state) is
                    when E_RESET =>
                        if (i2s_lrck_left = '1') then
                            state <= E_CAPTURE;
                            if (CONFIG = "01") then -- 01 is msb standard, 00 is Philips standard
                                sample_data_i2s <= sample_data_i2s(30 downto 0) & I2S_DATA;
                                i2s_shift_cnt   <= i2s_shift_cnt + 1;
                            end if;
                        end if;

                    when E_CAPTURE =>
                        --sample_data_i2s <= I2S_DATA & sample_data_i2s(31 downto 1);
                        sample_data_i2s <= sample_data_i2s(30 downto 0) & I2S_DATA;
                        i2s_shift_cnt   <= i2s_shift_cnt + 1; -- rollover
                        if (i2s_shift_cnt = 31) then
                            sample_en_i2s <= '1';
                        end if;

                    when others =>
                        null;
                end case;
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
    sample_cdc : data_cdc
        generic map (
            G_DATA_BITS => 32)
        port map (
            CLK_IN     => I2S_BCK,
            ARST_IN_N  => ARST_I2S_N,
            CLK_OUT    => CLK_AVL,
            ARST_OUT_N => ARST_AVL_N,
            DIN        => sample_data_i2s,
            DIN_EN     => sample_en_i2s,
            DOUT       => SAMPLE_DATA,
            DOUT_EN    => SAMPLE_EN);

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
