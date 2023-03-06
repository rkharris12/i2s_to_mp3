----------------------------------------------------------------------------------
-- Richie Harris
-- rkharris12@gmail.com
-- 2/22/2023
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity i2s_to_mp3_tb is
    
end i2s_to_mp3_tb;

architecture sim of i2s_to_mp3_tb is

    component i2s_to_mp3 is
        port (
            I2S_LRCK : in  std_logic; -- GPIO 26 on ESP
            I2S_BCK  : in  std_logic; -- GPIO 27 on ESP
            I2S_DATA : in  std_logic; -- GPIO 25 on ESP
            SPARE_IN : in  std_logic; -- GPIO 33 on ESP
            ESP_EN   : out std_logic; -- EN
            ESP_3V3  : in  std_logic  -- 3V3
        );
    end component;

    constant C_BCK_PERIOD : time := 0.9 us; -- not the real rate, but close

    signal i2s_lrck : std_logic := '1';
    signal i2s_bck  : std_logic := '0'; -- so lrck and data change on falling edge
    signal i2s_data : std_logic := '1';
    

begin

    i2s_lrck <= not i2s_lrck after C_BCK_PERIOD*16;
    i2s_bck  <= not i2s_bck after C_BCK_PERIOD/2;
    i2s_data <= not i2s_data after C_BCK_PERIOD;

    uut : i2s_to_mp3
        port map (
            I2S_LRCK => i2s_lrck,
            I2S_BCK  => i2s_bck,
            I2S_DATA => i2s_data,
            SPARE_IN => '0',
            ESP_EN   => open,
            ESP_3V3  => '0');

end sim;
