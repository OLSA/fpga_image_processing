library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx is
    port (
        clk     : in  std_logic;
        rst     : in  std_logic;  -- active-high reset
        data_in : in  std_logic_vector(7 downto 0);
        send    : in  std_logic;
        tx      : out std_logic;
        busy    : out std_logic
    );
end entity;

architecture rtl of uart_tx is
    constant CLK_FREQ : integer := 12000000;
    constant BAUD     : integer := 115200;
    constant BAUD_DIV : integer := CLK_FREQ / BAUD;  -- ~104

    type state_t is (IDLE, START, DATA, STOP);
    signal state     : state_t := IDLE;

    signal baud_cnt  : integer range 0 to BAUD_DIV-1 := 0;
    signal bit_idx   : integer range 0 to 7 := 0;

    signal shreg     : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_reg    : std_logic := '1';
begin
    tx <= tx_reg;

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state    <= IDLE;
                baud_cnt <= 0;
                bit_idx  <= 0;
                shreg    <= (others => '0');
                tx_reg   <= '1';
                busy     <= '0';
            else
                case state is
                    when IDLE =>
                        busy   <= '0';
                        tx_reg <= '1';
                        baud_cnt <= 0;
                        bit_idx  <= 0;
                        if send = '1' then
                            shreg <= data_in;
                            busy  <= '1';
                            state <= START;
                        end if;

                    when START =>
                        busy <= '1';
                        tx_reg <= '0';
                        if baud_cnt = BAUD_DIV-1 then
                            baud_cnt <= 0;
                            state <= DATA;
                            bit_idx <= 0;
                        else
                            baud_cnt <= baud_cnt + 1;
                        end if;

                    when DATA =>
                        busy <= '1';
                        tx_reg <= shreg(bit_idx);
                        if baud_cnt = BAUD_DIV-1 then
                            baud_cnt <= 0;
                            if bit_idx = 7 then
                                state <= STOP;
                            else
                                bit_idx <= bit_idx + 1;
                            end if;
                        else
                            baud_cnt <= baud_cnt + 1;
                        end if;

                    when STOP =>
                        busy <= '1';
                        tx_reg <= '1';
                        if baud_cnt = BAUD_DIV-1 then
                            baud_cnt <= 0;
                            state <= IDLE;
                        else
                            baud_cnt <= baud_cnt + 1;
                        end if;
                end case;
            end if;
        end if;
    end process;

end architecture;
