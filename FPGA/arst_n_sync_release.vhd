----------------------------------------------------------------------------------
-- Richie Harris
-- rkharris12@gmail.com
-- 2/23/2023
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity arst_n_sync_release is
    port (
        CLK        : in  std_logic;
        ARST_IN_N  : in  std_logic;
        ARST_OUT_N : out std_logic
    );
end arst_n_sync_release;

architecture rtl of arst_n_sync_release is

begin

    process(CLK, ARST_IN_N) begin
        if (ARST_IN_N = '0') then
            ARST_OUT_N <= '0';
        elsif rising_edge(CLK) then
            ARST_OUT_N <= '1'; -- could be a shift register and shift in a '1'
        end if;
    end process;

end rtl;
