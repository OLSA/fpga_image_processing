library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- RGB565 invert (u boji), sa valid handshake (kao ostali filteri)
entity filter_invert_rgb565 is
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        pixel_in  : in  std_logic_vector(15 downto 0);
        valid_in  : in  std_logic;
        pixel_out : out std_logic_vector(15 downto 0);
        valid_out : out std_logic
    );
end entity;

architecture rtl of filter_invert_rgb565 is
    signal out_reg : std_logic_vector(15 downto 0) := (others => '0');
    signal v_reg   : std_logic := '0';
begin
    pixel_out <= out_reg;
    valid_out <= v_reg;

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                out_reg <= (others => '0');
                v_reg   <= '0';
            else
                v_reg <= valid_in;
                if valid_in = '1' then
                    out_reg <= not pixel_in; -- RGB565 invert
                end if;
            end if;
        end if;
    end process;

end architecture;
