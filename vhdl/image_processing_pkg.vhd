library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package image_processing_pkg is

    --------------------------------------------------------------------
    -- Image dimensions
    --------------------------------------------------------------------
    constant IMG_WIDTH  : integer := 200;
    constant IMG_HEIGHT : integer := 200;
    constant PIXELS     : integer := IMG_WIDTH * IMG_HEIGHT;
	
	--------------------------------------------------------------------
    -- Image dimensions as bytes (UART header)
    --------------------------------------------------------------------
    constant WIDTH_BYTE  : std_logic_vector(7 downto 0) :=
        std_logic_vector(to_unsigned(IMG_WIDTH, 8));

    constant HEIGHT_BYTE : std_logic_vector(7 downto 0) :=
        std_logic_vector(to_unsigned(IMG_HEIGHT, 8));

    --------------------------------------------------------------------
    -- DIP switch config
    --------------------------------------------------------------------
    constant SW_INVERT    : std_logic_vector(1 downto 0) := "00";
    constant SW_THRESHOLD : std_logic_vector(1 downto 0) := "01";
    constant SW_GRAYSCALE : std_logic_vector(1 downto 0) := "10";
    constant SW_SOBEL     : std_logic_vector(1 downto 0) := "11";

    --------------------------------------------------------------------
    -- UART protocol: frame header sync markers
    --------------------------------------------------------------------
    constant SYNC_BYTE_0 : std_logic_vector(7 downto 0) := x"AA";
    constant SYNC_BYTE_1 : std_logic_vector(7 downto 0) := x"55";

end package;
