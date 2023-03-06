----------------------------------------------------------------------------------
-- Richie Harris
-- rkharris12@gmail.com
-- 2/22/2023
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity soc_wrapper is
    port (
        ARST_AVL_N             : out std_logic_vector(0 to 0) := "0";
        CLK_AVL                : out std_logic := '1';
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
        S_AVALON_readdata      : out std_logic_vector(31 downto 0);
        S_AVALON_readdatavalid : out std_logic;
        S_AVALON_waitrequest   : out std_logic;
        S_AVALON_write         : in  std_logic;
        S_AVALON_writedata     : in  std_logic_vector(31 downto 0)
    );
end soc_wrapper;

architecture sim of soc_wrapper is

    constant C_CLK_AVL_PERIOD : time := 20 ns; -- 50 MHz

begin

    -- clock and reset
    CLK_AVL  <= not CLK_AVL after C_CLK_AVL_PERIOD/2;

    -- write the capture address, then start a capture
    process begin
        M_AVALON_address    <= (others => '0');
        M_AVALON_byteenable <= (others => '0');
        M_AVALON_read       <= '0';
        M_AVALON_write      <= '0';
        M_AVALON_writedata  <= (others => '0');
        ARST_AVL_N(0)       <= '0';

        wait for 16*C_CLK_AVL_PERIOD;

        ARST_AVL_N(0)       <= '1';

        wait for 20*C_CLK_AVL_PERIOD;

        M_AVALON_address    <= std_logic_vector(to_unsigned(2, M_AVALON_address'length));
        M_AVALON_byteenable <= (others => '1');
        M_AVALON_write      <= '1';
        M_AVALON_writedata  <= x"16800000";

        wait for C_CLK_AVL_PERIOD;

        M_AVALON_address    <= (others => '0');
        M_AVALON_byteenable <= (others => '0');
        M_AVALON_write      <= '0';
        M_AVALON_writedata  <= (others => '0');

        wait for C_CLK_AVL_PERIOD;

        M_AVALON_address    <= std_logic_vector(to_unsigned(1, M_AVALON_address'length));
        M_AVALON_byteenable <= (others => '1');
        M_AVALON_write      <= '1';
        M_AVALON_writedata  <= x"00000001";

        wait for C_CLK_AVL_PERIOD;

        M_AVALON_address    <= (others => '0');
        M_AVALON_byteenable <= (others => '0');
        M_AVALON_write      <= '0';
        M_AVALON_writedata  <= (others => '0');

        wait;
    end process;

    -- not using the avalon slave read
    S_AVALON_readdata      <= (others => '0');
    S_AVALON_readdatavalid <= '0';
    S_AVALON_waitrequest   <= '0';

end sim;
