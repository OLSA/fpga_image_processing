-- ============================================================================
--  File: top_image_processing.vhd
--
--  Top-level modul sistema za obradu slike na FPGA.
--  Modul integriše memorijski podsistem (BlockRAM), paralelne filtere
--  (Invert, Grayscale, Threshold, Sobel), FSM kontroler, izlazni
--  multiplekser i UART transmiter.
--
--  Sistem čita piksele iz memorije u raster-scan redoslijedu, paralelno
--  ih prosljeđuje filterima, a izlaz izabranog filtera šalje sekvencijalno
--  preko UART interfejsa ka računaru.
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.image_processing_pkg.all;

entity top_image_processing is
    port (
        clk     : in  std_logic;
        start_n : in  std_logic; -- start (active-low)
        sw1_n   : in  std_logic;
        sw2_n   : in  std_logic;
        uart_tx : out std_logic
    );
end entity;

architecture rtl of top_image_processing is

    --------------------------------------------------------------------
    -- DIP switches
    --------------------------------------------------------------------
    signal sw1, sw2              : std_logic;
    signal switches_current      : std_logic_vector(1 downto 0);
    signal switches_selected     : std_logic_vector(1 downto 0) := SW_INVERT;

    --------------------------------------------------------------------
    -- Power-up reset (~87ms @ 12MHz)
    --------------------------------------------------------------------
    signal reset         : std_logic := '1';
    signal reset_counter : unsigned(19 downto 0) := (others => '0');
	constant RESET_COUNTER_MAX : unsigned(reset_counter'range) := (others => '1');

    --------------------------------------------------------------------
    -- Start button edge detection
    --------------------------------------------------------------------
    signal start_prev  : std_logic := '1';
    signal start_pulse : std_logic := '0';

    --------------------------------------------------------------------
    -- RAM interface
    --------------------------------------------------------------------
    signal ram_address     : integer range 0 to PIXELS*2-1 := 0;
    signal ram_byte        : std_logic_vector(7 downto 0);
    signal pixel_low_byte  : std_logic_vector(7 downto 0) := (others => '0');
    signal pixel_rgb565    : std_logic_vector(15 downto 0) := (others => '0');

    --------------------------------------------------------------------
    -- UART interface
    --------------------------------------------------------------------
    signal tx_data    : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_send    : std_logic := '0';
    signal tx_busy    : std_logic;
    signal tx_pending : std_logic := '0';

    --------------------------------------------------------------------
    -- Frame protocol
    --------------------------------------------------------------------
    signal bytes_per_pixel : integer range 1 to 2 := 1;
    signal operation_id    : std_logic_vector(7 downto 0);
    signal payload_size    : unsigned(31 downto 0) := (others => '0');

    --------------------------------------------------------------------
    -- Filter control
    --------------------------------------------------------------------
    signal filters_reset : std_logic := '0';
    signal pixel_valid   : std_logic := '0';

    --------------------------------------------------------------------
    -- Filter outputs - Invert RGB565
    --------------------------------------------------------------------
    signal invert_out   : std_logic_vector(15 downto 0);
    signal invert_valid : std_logic;

    --------------------------------------------------------------------
    -- Filter outputs - Threshold
    --------------------------------------------------------------------
    signal threshold_out   : std_logic_vector(7 downto 0);
    signal threshold_valid : std_logic;

    --------------------------------------------------------------------
    -- Filter outputs - Grayscale
    --------------------------------------------------------------------
    signal grayscale_out   : std_logic_vector(7 downto 0);
    signal grayscale_valid : std_logic;

    --------------------------------------------------------------------
    -- Filter outputs - Sobel
    --------------------------------------------------------------------
    signal sobel_out   : std_logic_vector(7 downto 0);
    signal sobel_valid : std_logic;

    --------------------------------------------------------------------
    -- Selected filter output (multiplexed)
    --------------------------------------------------------------------
    signal output_8bit        : std_logic_vector(7 downto 0) := (others => '0');
    signal output_8bit_valid  : std_logic := '0';
    signal output_16bit       : std_logic_vector(15 downto 0) := (others => '0');
    signal byte_select        : std_logic := '0';

    --------------------------------------------------------------------
    -- FSM
    --------------------------------------------------------------------
    type state_t is (

			------------------------------------------------------------------
			-- Idle / Initialization
			------------------------------------------------------------------
			IDLE,               -- Sistem miruje i čeka pritisak start dugmeta
			INIT_PROCESSING,    -- Uzimanje stanja prekidača i računanje parametara obrade
			RESET_FILTERS,      -- Kratki reset filtera (čišćenje internih registara, npr. Sobel)

			------------------------------------------------------------------
			-- Header transmission (šalje se jednom na početku obrade)
			------------------------------------------------------------------
			HDR_PREP,           -- Priprema sljedeći bajt zaglavlja
			HDR_SEND,           -- Slanje bajta zaglavlja kada je UART slobodan

			------------------------------------------------------------------
			-- Pixel processing loop: RAM → FILTER → UART payload
			------------------------------------------------------------------
			RAM_SET_LOW,        -- Postavlja adresu RAM-a za niži bajt piksela
			RAM_WAIT_LOW,       -- Čeka 1 takt zbog sinhrone latencije RAM-a
			RAM_CAP_LOW,        -- Učitava niži bajt piksela iz RAM-a

			RAM_SET_HIGH,       -- Postavlja adresu RAM-a za viši bajt piksela
			RAM_WAIT_HIGH,      -- Čeka 1 takt zbog sinhrone latencije RAM-a
			RAM_CAP_HIGH,       -- Učitava viši bajt i formira 16-bitni RGB565 piksel

			PROCESS_PIXEL,      -- Predaje ulazni piksel filterima (valid impuls)
			WAIT_FILTER,        -- Čeka da izabrani filter završi obradu piksela

			PAYLOAD_PREP,       -- Priprema bajt rezultata za slanje (low ili high dio)
			PAYLOAD_SEND        -- Šalje 1B ili 2B po pikselu (jedan ili dva UART prenosa)

		);


    signal state        : state_t := IDLE;
    signal header_index : integer range 0 to 8 := 0;
    signal pixel_index  : integer range 0 to PIXELS-1 := 0;

begin

    sw1 <= not sw1_n;
    sw2 <= not sw2_n;
    switches_current <= sw2 & sw1;

    u_ram : entity work.image_ram
        port map (
            clk  => clk,
            addr => ram_address, -- Adresa bajta u RAM-u koji se trenutno čita
            q    => ram_byte     -- 8-bitni izlaz; 16-bitni piksel se formira čitanjem 2 bajta (low+high)
        );

    u_tx : entity work.uart_tx
        port map (
            clk     => clk,
            rst     => reset,
            data_in => tx_data, -- Bajt koji se šalje preko UART-a
            send    => tx_send, -- Jednokratni impuls za pokretanje slanja bajta
            tx      => uart_tx, -- Serijski TX izlaz (ide na fizički UART pin)
            busy    => tx_busy  -- Indikator da UART trenutno šalje podatak
        );

    u_invert : entity work.filter_invert_rgb565
        port map (
            clk       => clk,
            rst       => reset or filters_reset,
            pixel_in  => pixel_rgb565,
            valid_in  => pixel_valid,
            pixel_out => invert_out,
            valid_out => invert_valid
        );

    u_thr : entity work.filter_treshold
        port map (
            clk       => clk,
            rst       => reset or filters_reset,
            pixel_in  => pixel_rgb565,
            valid_in  => pixel_valid,
            pixel_out => threshold_out,
            valid_out => threshold_valid
        );

    u_gry : entity work.filter_grayscale
        port map (
            clk       => clk,
            rst       => reset or filters_reset,
            pixel_in  => pixel_rgb565,
            valid_in  => pixel_valid,
            pixel_out => grayscale_out,
            valid_out => grayscale_valid
        );

    u_sob : entity work.filter_sobel
        generic map (
            IMG_WIDTH  => IMG_WIDTH,
            IMG_HEIGHT => IMG_HEIGHT
        )
        port map (
            clk       => clk,
            rst       => reset or filters_reset,
            pixel_in  => pixel_rgb565,
            valid_in  => pixel_valid,
            pixel_out => sobel_out,
            valid_out => sobel_valid
        );

    --------------------------------------------------------------------
	-- Output multiplexer
	-- Kombinacioni izbor izlaza filtera.
	-- Filter se bira na startu i ostaje nepromijenjen tokom obrade.
	--------------------------------------------------------------------
    process(switches_selected, threshold_out, threshold_valid, 
            grayscale_out, grayscale_valid, sobel_out, sobel_valid)
    begin
	    
		case switches_selected is
			when SW_THRESHOLD =>
				output_8bit       <= threshold_out;
				output_8bit_valid <= threshold_valid;

			when SW_GRAYSCALE =>
				output_8bit       <= grayscale_out;
				output_8bit_valid <= grayscale_valid;

			when SW_SOBEL =>
				output_8bit       <= sobel_out;
				output_8bit_valid <= sobel_valid;

			-- SW_INVERT: nema 8-bitni izlaz
			when others =>
				output_8bit       <= (others => '0');
				output_8bit_valid <= '0';
		end case;
    end process;

    --------------------------------------------------------------------
    -- Main FSM
    --------------------------------------------------------------------
    process(clk)        
    begin
        if rising_edge(clk) then

            -- Power-up reset
            if reset = '1' then
				if reset_counter = RESET_COUNTER_MAX then
					reset <= '0';                       
				else
					reset_counter <= reset_counter + 1;
				end if;
			end if;

            -- Defaults
            tx_send       <= '0';
            pixel_valid   <= '0';
            filters_reset <= '0';
            start_pulse   <= '0';

            -- Edge detection
            if (start_prev = '1') and (start_n = '0') then
                start_pulse <= '1';
            end if;
            start_prev <= start_n;

            -- FSM during reset
            if reset = '1' then
                state        <= IDLE;
                tx_pending   <= '0';
                header_index <= 0;
                pixel_index  <= 0;
                byte_select  <= '0';

            else
                case state is

                    when IDLE =>
                        if start_pulse = '1' then
                            switches_selected <= switches_current;
                            state <= INIT_PROCESSING;
                        end if;

                    when INIT_PROCESSING =>
					    -- Filter ID za Python: 2-bitni kod DIP prekidača proširen na 8 bita                        
						operation_id <= "000000" & switches_selected;

						if switches_selected = SW_INVERT then
							bytes_per_pixel <= 2;
							payload_size    <= to_unsigned(PIXELS * 2, 32);
						else
							bytes_per_pixel <= 1;
							payload_size    <= to_unsigned(PIXELS * 1, 32);
						end if;

						pixel_index  <= 0;
						header_index <= 0;
						byte_select  <= '0';

						state <= RESET_FILTERS;


                    when RESET_FILTERS =>
                        filters_reset <= '1';
                        state <= HDR_PREP;

                    when HDR_PREP =>
                        tx_pending <= '1';
                        state <= HDR_SEND;

                    when HDR_SEND =>
					
                        -- UART zaglavlje (9 bajtova):
						-- [0–1]  sync bajtovi (0xAA, 0x55)
						-- [2–5]  veličina payload-a (32-bit, LSB first)
						-- [6]    operation_id (ID izabranog filtera)
						-- [7]    širina slike
						-- [8]    visina slike
	
                        if (tx_pending = '1') and (tx_busy = '0') then
                            case header_index is
                                when 0 => tx_data <= SYNC_BYTE_0;
                                when 1 => tx_data <= SYNC_BYTE_1;
                                when 2 => tx_data <= std_logic_vector(payload_size(7 downto 0));
                                when 3 => tx_data <= std_logic_vector(payload_size(15 downto 8));
                                when 4 => tx_data <= std_logic_vector(payload_size(23 downto 16));
                                when 5 => tx_data <= std_logic_vector(payload_size(31 downto 24));
                                when 6 => tx_data <= operation_id;
                                when 7 => tx_data <= WIDTH_BYTE;
                                when 8 => tx_data <= HEIGHT_BYTE;
                                when others => tx_data <= x"00";
                            end case;

                            tx_send    <= '1';
                            tx_pending <= '0';

                            if header_index = 8 then
                                state <= RAM_SET_LOW;
                            else
                                header_index <= header_index + 1;
                                state <= HDR_PREP;
                            end if;
                        end if;

                    when RAM_SET_LOW =>                        
                        ram_address <= pixel_index * 2;
                        state <= RAM_WAIT_LOW;

                    when RAM_WAIT_LOW =>
                        state <= RAM_CAP_LOW;

                    when RAM_CAP_LOW =>
                        pixel_low_byte <= ram_byte;
                        state <= RAM_SET_HIGH;

                    when RAM_SET_HIGH =>                        
                        ram_address <= (pixel_index * 2) + 1;
                        state <= RAM_WAIT_HIGH;

                    when RAM_WAIT_HIGH =>
                        state <= RAM_CAP_HIGH;

                    when RAM_CAP_HIGH =>
                        pixel_rgb565 <= ram_byte & pixel_low_byte;
                        state <= PROCESS_PIXEL;

                    when PROCESS_PIXEL =>
                        pixel_valid <= '1';
                        state <= WAIT_FILTER;

                    when WAIT_FILTER =>
                        if bytes_per_pixel = 2 then
                            if invert_valid = '1' then
                                output_16bit <= invert_out;
                                state <= PAYLOAD_PREP;
                            end if;
                        else
                            if output_8bit_valid = '1' then
                                state <= PAYLOAD_PREP;
                            end if;
                        end if;

                    when PAYLOAD_PREP =>
                        tx_pending <= '1';
                        state <= PAYLOAD_SEND;

                    when PAYLOAD_SEND =>
                        if (tx_pending = '1') and (tx_busy = '0') then
                            if bytes_per_pixel = 2 then
                                if byte_select = '0' then
                                    tx_data <= output_16bit(7 downto 0);
                                    byte_select <= '1';
                                    tx_send <= '1';
                                    tx_pending <= '0';
                                    state <= PAYLOAD_PREP;
                                else
                                    tx_data <= output_16bit(15 downto 8);
                                    byte_select <= '0';
                                    tx_send <= '1';
                                    tx_pending <= '0';

                                    if pixel_index = PIXELS-1 then
                                        state <= IDLE;
                                    else
                                        pixel_index <= pixel_index + 1;
                                        state <= RAM_SET_LOW;
                                    end if;
                                end if;

                            else
                                tx_data <= output_8bit;
                                tx_send <= '1';
                                tx_pending <= '0';

                                if pixel_index = PIXELS-1 then
                                    state <= IDLE;
                                else
                                    pixel_index <= pixel_index + 1;
                                    state <= RAM_SET_LOW;
                                end if;
                            end if;
                        end if;

                end case;
            end if;
        end if;
    end process;

end architecture;
