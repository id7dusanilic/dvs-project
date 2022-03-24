library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity RAM_writer is
    generic (
        G_RAM_DATA_WIDTH    : natural;
        G_RAM_ADDR_WIDTH    : natural
    );
    port (
        clk                     : in  std_logic;
        reset                   : in  std_logic;
        asi_input_data_data     : in  std_logic_vector;
        asi_input_data_valid    : in  std_logic;
        asi_input_data_ready    : out std_logic;
        asi_input_data_sop      : in  std_logic;
        asi_input_data_eop      : in  std_logic;

        rd                      : in  std_logic;
        rd_addr                 : in  std_logic_vector;

        row_length              : in  std_logic_vector;

        data_out_0              : out std_logic_vector;
        data_out_1              : out std_logic_vector;

        ram_sel                 : out std_logic;
        ram_filled              : out std_logic_vector(1 downto 0);

        ram_reset               : in  std_logic_vector(1 downto 0)
    );
end entity RAM_writer;

architecture rtl of RAM_writer is
    constant C_RAM_DEPTH    : natural := 2**G_RAM_ADDR_WIDTH;

    type ram_addr_t     is array (0 to 1) of std_logic_vector(G_RAM_ADDR_WIDTH-1 downto 0);
    type ram_counter_t  is array (0 to 1) of integer range 0 to C_RAM_DEPTH-1;

    signal r_ram_sel        : std_logic;
    signal r_ram_filled     : std_logic_vector(1 downto 0);

    signal w_wr             : std_logic;
    signal w_wr_array       : std_logic_vector(1 downto 0);
    signal w_wr_addr        : ram_addr_t;
    signal c_wr_addr        : ram_counter_t;

    signal c_rd_column      : ram_counter_t;

    signal w_data_in        : std_logic_vector(G_RAM_DATA_WIDTH-1 downto 0);

    signal w_asi_input_data_ready : std_logic;

begin

    RAM_i0: entity work.RAM
        generic map (
            G_DATA_WIDTH => G_RAM_DATA_WIDTH,
            G_ADDR_WIDTH => G_RAM_ADDR_WIDTH
        )
        port map (
            clk => clk,
            rd => rd,
            wr => w_wr_array(0),
            rd_addr => rd_addr,
            wr_addr => w_wr_addr(0),
            data_in => w_data_in,
            data_out => data_out_0
        );

    RAM_i1: entity work.RAM
        generic map (
            G_DATA_WIDTH => G_RAM_DATA_WIDTH,
            G_ADDR_WIDTH => G_RAM_ADDR_WIDTH
        )
        port map (
            clk => clk,
            rd => rd,
            wr => w_wr_array(1),
            rd_addr => rd_addr,
            wr_addr => w_wr_addr(1),
            data_in => w_data_in,
            data_out => data_out_1
        );

    w_data_in <= asi_input_data_data;

    -- Conversions
    w_wr_addr(0) <= std_logic_vector(to_unsigned(c_wr_addr(0), G_RAM_ADDR_WIDTH));
    w_wr_addr(1) <= std_logic_vector(to_unsigned(c_wr_addr(1), G_RAM_ADDR_WIDTH));

    -- Ready for next data when at least one RAM is not filled
    w_asi_input_data_ready <= not (r_ram_filled(0) and r_ram_filled(1));

    -- Activate write signal when there is data is valid, and ready for data
    w_wr <= (asi_input_data_valid and w_asi_input_data_ready);
    -- Generating write signal for each RAM
    w_wr_array(0) <= w_wr and not r_ram_filled(0) and not r_ram_sel;
    w_wr_array(1) <= w_wr and not r_ram_filled(1) and r_ram_sel;

    WRITE_POSITION: process (clk) is
        variable v_row_length   : integer;
        variable v_ram_sel      : integer range 0 to 1;
    begin
        if rising_edge(clk) then
            -- Variable init
            v_row_length := to_integer(unsigned(row_length));
            v_ram_sel := 1 when r_ram_sel='1' else 0;

            -- If writing to currently selected RAM increment write address
            if w_wr_array(v_ram_sel)='1' then
                c_wr_addr(v_ram_sel) <= c_wr_addr(v_ram_sel) + 1;
                -- If at the end of a row
                if c_wr_addr(v_ram_sel) = v_row_length-1 then
                    c_wr_addr(v_ram_sel) <= 0;
                end if;
            end if;

            if reset='1' then
                c_wr_addr(0) <= 0;
                c_wr_addr(1) <= 0;
            end if;
        end if;
    end process WRITE_POSITION;

    RAM_FILLED_STATUSES: process (clk) is
        variable v_row_length   : integer;
        variable v_ram_sel      : integer range 0 to 1;
    begin
        if rising_edge(clk) then
            -- Variable init
            v_row_length := to_integer(unsigned(row_length));
            v_ram_sel := 1 when r_ram_sel='1' else 0;

            -- If writing to currently selected RAM
            if w_wr_array(v_ram_sel)='1' then
                -- If at the end of a row
                if c_wr_addr(v_ram_sel) = v_row_length-1 then
                    r_ram_filled(v_ram_sel) <= '1';
                end if;
            end if;

            -- Reset RAM filled flags
            if ram_reset(0) = '1' then
                r_ram_filled(0) <= '0';
            end if;

            if ram_reset(1) = '1' then
                r_ram_filled(1) <= '0';
            end if;

            if reset='1' then
                r_ram_filled <= (others => '0');
            end if;
        end if;
    end process RAM_FILLED_STATUSES;

    RAM_SELECT: process (clk) is
        variable v_row_length   : integer;
        variable v_ram_sel      : integer range 0 to 1;
    begin
        if rising_edge(clk) then
            -- Variable init
            v_row_length := to_integer(unsigned(row_length));
            v_ram_sel := 1 when r_ram_sel='1' else 0;

            -- If writing at the end of a row, toggle ram_sel
            if w_wr_array(v_ram_sel)='1' and c_wr_addr(v_ram_sel) = v_row_length-1 then
                r_ram_sel <= not r_ram_sel;
            end if;

            if reset='1' then
                r_ram_sel <= '0';
            end if;
        end if;
    end process RAM_SELECT;

    -- Assignments
    asi_input_data_ready <= w_asi_input_data_ready;
    ram_filled <= r_ram_filled;
    ram_sel <= r_ram_sel;

end architecture rtl; -- of RAM_writer
