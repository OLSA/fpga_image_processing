library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Threshold on 8-bit grayscale domain.
-- Matches the "prag" definition: out = 0xFF if gray >= T else 0x00
entity filter_treshold is
    generic (
        T : integer := 128
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        pixel_in  : in  std_logic_vector(15 downto 0);
        valid_in  : in  std_logic;
        pixel_out : out std_logic_vector(7 downto 0);
        valid_out : out std_logic
    );
end entity;

architecture rtl of filter_treshold is
    signal gray   : std_logic_vector(7 downto 0);
    signal v_gray : std_logic;
    signal out_reg: std_logic_vector(7 downto 0) := (others => '0');
    signal v_reg  : std_logic := '0';
begin
    u_gray : entity work.filter_grayscale
        port map (
            clk       => clk,
            rst       => rst,
            pixel_in  => pixel_in,
            valid_in  => valid_in,
            pixel_out => gray,
            valid_out => v_gray
        );

    pixel_out <= out_reg;
    valid_out <= v_reg;

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                out_reg <= (others => '0');
                v_reg   <= '0';
            else
                v_reg <= v_gray;
                if v_gray = '1' then
                    if unsigned(gray) >= to_unsigned(T, 8) then
                        out_reg <= x"FF";
                    else
                        out_reg <= x"00";
                    end if;
                end if;
            end if;
        end if;
    end process;
end architecture;
