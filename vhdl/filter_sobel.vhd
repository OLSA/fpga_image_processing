library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Sobel edge detector on grayscale domain.
-- Streaming: one pixel_in per valid_in, one output per valid_out (1-cycle latency).
entity filter_sobel is
    generic (
        IMG_WIDTH  : integer := 200;
        IMG_HEIGHT : integer := 200
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

architecture rtl of filter_sobel is
    type line_t is array (0 to IMG_WIDTH-1) of std_logic_vector(7 downto 0);
    signal line1, line2 : line_t;

    signal col : integer range 0 to IMG_WIDTH-1 := 0;
    signal row : integer range 0 to IMG_HEIGHT-1 := 0;

    signal sr0, sr1 : std_logic_vector(7 downto 0) := (others => '0');

    signal gray      : std_logic_vector(7 downto 0);
    signal v_gray    : std_logic;
    signal out_reg   : std_logic_vector(7 downto 0) := (others => '0');
    signal v_reg     : std_logic := '0';

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
        variable p00, p01, p02 : unsigned(7 downto 0);
        variable p10, p11, p12 : unsigned(7 downto 0);
        variable p20, p21, p22 : unsigned(7 downto 0);
        variable gx, gy        : integer;
        variable mag           : integer;
        variable sobel8        : std_logic_vector(7 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                out_reg <= (others => '0');
                v_reg   <= '0';
                col <= 0;
                row <= 0;
                sr0 <= (others => '0');
                sr1 <= (others => '0');
                for i in 0 to IMG_WIDTH-1 loop
                    line1(i) <= (others => '0');
                    line2(i) <= (others => '0');
                end loop;
            else
                v_reg <= v_gray;

                if v_gray = '1' then
                    -- Sobel window valid for row>=2 and col>=2, else border = 0
                    if (row >= 2) and (col >= 2) then
                        p00 := unsigned(line2(col-2));
                        p01 := unsigned(line2(col-1));
                        p02 := unsigned(line2(col));

                        p10 := unsigned(line1(col-2));
                        p11 := unsigned(line1(col-1));
                        p12 := unsigned(line1(col));

                        p20 := unsigned(sr0);
                        p21 := unsigned(sr1);
                        p22 := unsigned(gray);

                        gx := (to_integer(p02) - to_integer(p00))
                            + 2*(to_integer(p12) - to_integer(p10))
                            + (to_integer(p22) - to_integer(p20));

                        gy := (to_integer(p00) + 2*to_integer(p01) + to_integer(p02))
                            - (to_integer(p20) + 2*to_integer(p21) + to_integer(p22));

                        if gx < 0 then gx := -gx; end if;
                        if gy < 0 then gy := -gy; end if;

                        mag := gx + gy;

                        if mag > 255 then
                            sobel8 := x"FF";
                        else
                            sobel8 := std_logic_vector(to_unsigned(mag, 8));
                        end if;
                    else
                        sobel8 := x"00";
                    end if;

                    out_reg <= sobel8;

                    -- update line buffers & shift regs (using current gray)
                    line2(col) <= line1(col);
                    line1(col) <= gray;

                    sr0 <= sr1;
                    sr1 <= gray;

                    -- advance col/row
                    if col = IMG_WIDTH-1 then
                        col <= 0;
                        if row = IMG_HEIGHT-1 then
                            row <= 0;
                        else
                            row <= row + 1;
                        end if;
                        -- reset shift regs at start of new row
                        sr0 <= (others => '0');
                        sr1 <= (others => '0');
                    else
                        col <= col + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;
end architecture;
