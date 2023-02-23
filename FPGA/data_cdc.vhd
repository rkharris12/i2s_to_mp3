----------------------------------------------------------------------------------
-- Richie Harris
-- rkharris12@gmail.com
-- 5/23/2021
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity data_cdc is
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
end data_cdc;

architecture rtl of data_cdc is

    signal toggle    : std_logic;
    signal toggle_sr : std_logic_vector(3 downto 0);

    signal din_i     : std_logic_vector(G_DATA_BITS-1 downto 0);
    signal dout_en_i : std_logic;

begin

    -- input toggle
    process(CLK_IN, ARST_IN_N) begin
        if (ARST_IN_N = '0') then
            toggle <= '0';
        elsif rising_edge(CLK_IN) then
            toggle <= toggle xor DIN_EN;
        end if;
    end process;

    -- latch input data on input clock
    process(CLK_IN, ARST_IN_N) begin
        if (ARST_IN_N = '0') then
            din_i <= (others => '0');
        elsif rising_edge(CLK_IN) then
            if (DIN_EN = '1') then
                din_i <= DIN;
            end if;
        end if;
    end process;

    -- toggle resync
    process(CLK_OUT, ARST_OUT_N) begin
        if (ARST_OUT_N = '0') then
            toggle_sr <= (others => '0');
        elsif rising_edge(CLK_OUT) then
            toggle_sr <= toggle_sr(toggle_sr'high - 1 downto 0) & toggle;
        end if;
    end process;

    -- latch data sitting on bus to output clock
    process(CLK_OUT, ARST_OUT_N) begin
        if (ARST_OUT_N = '0') then
            DOUT    <= (others => '0');
            DOUT_EN <= '0';
        elsif rising_edge(CLK_OUT) then
            DOUT_EN <= '0';

            if (dout_en_i = '1') then
                DOUT    <= din_i;
                DOUT_EN <= '1';
            end if;
        end if;
    end process;

    dout_en_i <= toggle_sr(toggle_sr'high) xor toggle_sr(toggle_sr'high - 1);

end rtl;
