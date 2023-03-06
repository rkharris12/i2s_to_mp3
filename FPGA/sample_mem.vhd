----------------------------------------------------------------------------------
-- Richie Harris
-- rkharris12@gmail.com
-- 2/22/2023
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity sample_mem is
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
end sample_mem;

architecture sim of sample_mem is

    type slv_array_type is array (natural range <>) of std_logic_vector;
    signal mem : slv_array_type(65535 downto 0)(31 downto 0);

begin

    process(clka) begin
        if rising_edge(clka) then
            if (wea(0) = '1') then
                mem(to_integer(unsigned(addra))) <= dina;
            end if;
        end if;
    end process;

    process(clkb) begin
        if rising_edge(clkb) then
            doutb <= mem(to_integer(unsigned(addrb)));
        end if;
    end process;

end sim;
