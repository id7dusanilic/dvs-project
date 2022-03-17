library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.ALL;

entity RAM is
    generic (
        G_DATA_WIDTH    : natural := 18;
        G_ADDR_WIDTH    : natural := 13
    );
    port (
        clk         : in    std_logic;

        rd          : in    std_logic;
        wr          : in    std_logic;
        rd_addr     : in    std_logic_vector(G_ADDR_WIDTH - 1 downto 0);
        wr_addr     : in    std_logic_vector(G_ADDR_WIDTH - 1 downto 0);

        data_in     : in    std_logic_vector(G_DATA_WIDTH - 1 downto 0);
        data_out    : out   std_logic_vector(G_DATA_WIDTH - 1 downto 0)
    );
end RAM;

architecture Behavioral of RAM is
    type RAM_t is array (0 to 2**G_ADDR_WIDTH - 1) of std_logic_vector(G_DATA_WIDTH - 1 downto 0);

    signal memory : RAM_t := (others => (others => '0'));
    signal r_data : std_logic_vector(G_DATA_WIDTH - 1 downto 0);
begin

    READ_PROCESS : process(clk) is
    begin
        if rising_edge(clk) then
            if (rd = '1') then
                data_out <= memory(to_integer(unsigned(rd_addr)));
            end if;
        end if;
    end process;

    WRITE_PROCESS : process(clk) is
    begin
        if rising_edge(clk) then
            if (wr = '1') then
                memory(to_integer(unsigned(wr_addr))) <= data_in;
            end if;
        end if;
    end process;
end Behavioral;
