library IEEE;use IEEE.std_logic_1164.all; use IEEE.numeric_std.all;

use work.acc_bilinear_scaling_PK.all;

entity acc_bilinear_scaling is
    port (
        clk                           : in  std_logic := '0';
        reset                         : in  std_logic := '0';
        asi_input_data_data           : in  std_logic_vector(C_DATA_WIDTH-1 downto 0) := (others => '0');
        asi_input_data_valid          : in  std_logic := '0';
        asi_input_data_ready          : out std_logic;
        asi_input_data_sop            : in  std_logic := '0';
        asi_input_data_eop            : in  std_logic := '0';
        aso_output_data_data          : out std_logic_vector(C_DATA_WIDTH-1 downto 0);
        aso_output_data_endofpacket   : out std_logic;
        aso_output_data_startofpacket : out std_logic;
        aso_output_data_valid         : out std_logic;
        aso_output_data_ready         : in  std_logic := '0';
        params_address                : in  std_logic_vector(C_MM_ADDR_WIDTH-1 downto 0) := (others => '0');
        params_read                   : in  std_logic := '0';
        params_write                  : in  std_logic := '0';
        params_readdata               : out std_logic_vector(C_MM_DATA_WIDTH-1 downto 0);
        params_writedata              : in  std_logic_vector(C_MM_DATA_WIDTH-1 downto 0) := (others => '0');
        params_waitrequest            : out std_logic
    );
end entity acc_bilinear_scaling;

architecture rtl of acc_bilinear_scaling is
    type ram_signal_t   is array (0 to 1) of std_logic;
    type ram_data_t     is array (0 to 1) of std_logic_vector(C_DATA_WIDTH-1 downto 0);
    type ram_addr_t     is array (0 to 1) of std_logic_vector(C_ADDR_WIDTH-1 downto 0);
    type ram_counter_t  is array (0 to 1) of integer range 0 to C_RAM_DEPTH-1;
    type register_map_t is array (0 to 2**C_MM_ADDR_WIDTH-1) of std_logic_vector(C_MM_DATA_WIDTH - 1 downto 0);

    signal register_map     : register_map_t := (others => (others => '1'));

    signal r_sx             : std_logic_vector(C_MM_DATA_WIDTH-1 downto 0);
    signal r_sy             : std_logic_vector(C_MM_DATA_WIDTH-1 downto 0);
    signal r_sx_inv         : std_logic_vector(2*C_MM_DATA_WIDTH-1 downto 0);
    signal r_sy_inv         : std_logic_vector(2*C_MM_DATA_WIDTH-1 downto 0);
    signal r_width          : std_logic_vector(2*C_MM_DATA_WIDTH-1 downto 0);
    signal r_height         : std_logic_vector(2*C_MM_DATA_WIDTH-1 downto 0);

    signal w_width          : integer range 0 to 2**C_DIM_WIDTH;
    signal w_height         : integer range 0 to 2**C_DIM_WIDTH;

    signal r_ram_sel        : std_logic := '0'; -- The RAM that is being written to
    signal w_ram_sel        : integer range 0 to 1;

    signal r_rd             : std_logic := '0';
    signal w_wr_array       : ram_signal_t := (others => '0');
    signal c_wr_column      : ram_counter_t := (others => 0);
    signal w_wr_addr        : ram_addr_t := (others => (others => '0'));

    signal c_rd_column      : integer range 0 to C_RAM_DEPTH-1 := 0;
    signal w_rd_addr        : std_logic_vector(C_ADDR_WIDTH-1 downto 0) := (others => '0');

    signal r_data_in        : std_logic_vector(C_DATA_WIDTH-1 downto 0) := (others => '0');
    signal r_data_out       : ram_data_t := (others => (others => '0'));

    signal r_ram_filled     : ram_signal_t := (others => '0');
    signal w_processing     : std_logic;
    signal r_wr             : std_logic;

    signal w_asi_input_data_ready : std_logic := '0';

begin

    r_sx <= register_map(C_SX_ADDR);
    r_sy <= register_map(C_SY_ADDR);
    r_sx_inv <= register_map(C_SX_INV_ADDR+1) & register_map(C_SX_INV_ADDR);
    r_sy_inv <= register_map(C_SY_INV_ADDR+1) & register_map(C_SY_INV_ADDR);
    r_width <= register_map(C_WIDTH_ADDR+1) & register_map(C_WIDTH_ADDR);
    r_height <= register_map(C_HEIGHT_ADDR+1) & register_map(C_HEIGHT_ADDR);

    w_width <= to_integer(unsigned(r_width));
    w_height <= to_integer(unsigned(r_height));

    w_ram_sel <= 1 when r_ram_sel='1' else 0;

    WRITE_MM: process(clk) is
        variable v_address : integer range 0 to 2**C_MM_ADDR_WIDTH - 1;
    begin
        if rising_edge(clk) then
            v_address := to_integer(unsigned(params_address));
            if params_write = '1' then
                register_map(v_address) <= params_writedata;
            end if;
            if (reset = '1') then
                register_map <= (others => (others => '0'));
            end if;
        end if;
    end process WRITE_MM;

    READ_MM: process(clk) is
        variable v_address : integer range 0 to 2**C_MM_ADDR_WIDTH - 1;
    begin
        if rising_edge(clk) then
            v_address := to_integer(unsigned(params_address));
            if params_read = '1' then
                params_readdata <= register_map(v_address);
            end if;
            if (reset = '1') then
                params_readdata <= (others => '0');
            end if;
        end if;
    end process READ_MM;

    RAM_i0: entity work.RAM
        generic map (
            G_DATA_WIDTH => C_DATA_WIDTH,
            G_ADDR_WIDTH => C_ADDR_WIDTH
        )
        port map (
            clk => clk,
            rd => r_rd,
            wr => w_wr_array(0),
            rd_addr => w_rd_addr,
            wr_addr => w_wr_addr(0),
            data_in => r_data_in,
            data_out => r_data_out(0)
        );

    RAM_i1: entity work.RAM
        generic map (
            G_DATA_WIDTH => C_DATA_WIDTH,
            G_ADDR_WIDTH => C_ADDR_WIDTH
        )
        port map (
            clk => clk,
            rd => r_rd,
            wr => w_wr_array(1),
            rd_addr => w_rd_addr,
            wr_addr => w_wr_addr(1),
            data_in => r_data_in,
            data_out => r_data_out(1)
        );

    w_rd_addr <= std_logic_vector(to_unsigned(c_rd_column, C_ADDR_WIDTH));

    w_wr_addr(0) <= std_logic_vector(to_unsigned(c_wr_column(0), C_ADDR_WIDTH));
    w_wr_addr(1) <= std_logic_vector(to_unsigned(c_wr_column(1), C_ADDR_WIDTH));

    w_processing <= r_ram_filled(0) and r_ram_filled(1);
    w_asi_input_data_ready <= not w_processing;
    asi_input_data_ready <= w_asi_input_data_ready;

    r_rd <= w_processing;

    w_wr_array(0) <= r_wr and not r_ram_sel;
    w_wr_array(1) <= r_wr and r_ram_sel;

    COUNT: process (clk) is
    begin
        if rising_edge(clk) then
            -- Write address increment
            if w_wr_array(w_ram_sel)='1' then
                c_wr_column(w_ram_sel) <= c_wr_column(w_ram_sel) + 1;
                if c_wr_column(w_ram_sel) = w_width-1 then
                    c_wr_column(w_ram_sel) <= 0;
                    r_ram_filled(w_ram_sel) <= '1';
                end if;
            end if;

            -- Read address increment
            if r_rd='1' then
                c_rd_column <= c_rd_column + 1;
                if c_rd_column=w_width-1 then
                    c_rd_column <= 0;
                    r_ram_filled(w_ram_sel) <= '0';
                end if;
            end if;

            if reset='1' then
                c_wr_column(0) <= 0;
                c_wr_column(1) <= 0;
                c_rd_column <= 0;
            end if;
        end if;
    end process COUNT;

    RAM_SELECT: process (clk) is
    begin
        if rising_edge(clk) then
            if c_wr_column(w_ram_sel) = w_width-1 and w_wr_array(w_ram_sel)='1' then
                r_ram_sel <= not r_ram_sel;
            end if;
            if reset='1' then
                r_ram_sel <= '0';
            end if;
        end if;
    end process RAM_SELECT;

    process (clk) is
    begin
        if rising_edge(clk) then
            r_data_in <= asi_input_data_data;
            r_wr <= (asi_input_data_valid and w_asi_input_data_ready);
        end if;
    end process;

    -- TODO: Auto-generated HDL template

    aso_output_data_data <= "00000000";

    aso_output_data_startofpacket <= '0';

    aso_output_data_endofpacket <= '0';

    params_waitrequest <= '0';

end architecture rtl; -- of acc_bilinear_scaling
