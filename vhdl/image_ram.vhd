library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Byte-addressed image RAM initialized from image_200x200_rgb565.mif
entity image_ram is
    port (
        clk  : in  std_logic;
        addr : in  integer range 0 to 79999;
        q    : out std_logic_vector(7 downto 0)
    );
end entity;

architecture rtl of image_ram is
    type ram_t is array (0 to 79999) of std_logic_vector(7 downto 0);
    signal ram : ram_t;
    attribute ram_init_file : string;
    attribute ram_init_file of ram : signal is "image_200x200_rgb565.mif";
begin
    process(clk)
    begin
        if rising_edge(clk) then
            q <= ram(addr);
        end if;
    end process;
end architecture;
