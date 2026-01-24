library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- RGB565 -> 8-bit grayscale (streaming, 1 pixel per valid_in)
entity filter_grayscale is
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        pixel_in  : in  std_logic_vector(15 downto 0);
        valid_in  : in  std_logic;
        pixel_out : out std_logic_vector(7 downto 0);
        valid_out : out std_logic
    );
end entity;

architecture rtl of filter_grayscale is
    signal out_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal v_reg   : std_logic := '0';
begin
    pixel_out <= out_reg;
    valid_out <= v_reg;

    process(clk)
        variable r, g, b : unsigned(7 downto 0);
        variable sum     : unsigned(15 downto 0);
        variable hi, lo  : std_logic_vector(7 downto 0);
        variable gray8   : std_logic_vector(7 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                out_reg <= (others => '0');
                v_reg   <= '0';
            else
                v_reg <= valid_in;
                if valid_in = '1' then
                    hi := pixel_in(15 downto 8);
                    lo := pixel_in(7 downto 0);

                    -- Same approximation style as your working top_grayscale/top_sobel
                    r := shift_left(resize(unsigned(hi(7 downto 3)), 8), 3);
                    g := shift_left(resize(unsigned(hi(2 downto 0)), 8), 5)
                       + shift_left(resize(unsigned(lo(7 downto 5)), 8), 2);
                    b := shift_left(resize(unsigned(lo(4 downto 0)), 8), 3);

                    sum   := r * 77 + g * 150 + b * 29;
                    gray8 := std_logic_vector(sum(15 downto 8));

                    out_reg <= gray8;
                end if;
            end if;
        end if;
    end process;
end architecture;
