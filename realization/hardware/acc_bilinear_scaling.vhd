library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

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
		params_readdata               : out std_logic_vector(C_DIM_WIDTH-1 downto 0);
		params_writedata              : in  std_logic_vector(C_DIM_WIDTH-1 downto 0) := (others => '0');
		params_waitrequest            : out std_logic
	);
end entity acc_bilinear_scaling;

architecture rtl of acc_bilinear_scaling is
    type ram_signal_t   is array (integer range 0 to 1) of std_logic;
    type ram_data_t     is array (integer range 0 to 1) of std_logic_vector(C_DATA_WIDTH-1 downto 0);
    type ram_addr_t     is array (integer range 0 to 1) of std_logic_vector(C_ADDR_WIDTH-1 downto 0);
    type ram_counter_t  is array (integer range 0 to 1) of integer range 0 to C_RAM_DEPTH-1;

    signal r_sx             : std_logic_vector(C_SCALE_WIDTH-1 downto 0);
    signal r_sy             : std_logic_vector(C_SCALE_WIDTH-1 downto 0);
    signal r_sx_inv         : std_logic_vector(C_SCALE_INV_WIDTH-1 downto 0) := (0 => '1', others => '0');
    signal r_sy_inv         : std_logic_vector(C_SCALE_INV_WIDTH-1 downto 0) := (0 => '1', others => '0');
    signal r_width          : std_logic_vector(C_DIM_WIDTH-1 downto 0);
    signal r_height         : std_logic_vector(C_DIM_WIDTH-1 downto 0);

    signal w_strobe_sx      : std_logic;
    signal w_strobe_sy      : std_logic;
    signal w_strobe_sx_inv  : std_logic;
    signal w_strobe_sy_inv  : std_logic;
    signal w_strobe_width   : std_logic;
    signal w_strobe_height  : std_logic;

	signal w_read_mm        : std_logic_vector(params_readdata'range);

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

    w_width <= to_integer(unsigned(r_width));
    w_height <= to_integer(unsigned(r_height));

    w_ram_sel <= 1 when r_ram_sel='1' else 0;

    w_strobe_sx <= '1' when params_write = '1' and params_address = C_SX_ADDR else '0';
    w_strobe_sy <= '1' when params_write = '1' and params_address = C_SY_ADDR else '0';
    w_strobe_sx_inv <= '1' when params_write = '1' and params_address = C_SX_INV_ADDR else '0';
    w_strobe_sy_inv <= '1' when params_write = '1' and params_address = C_SY_INV_ADDR else '0';
    w_strobe_width <= '1' when params_write = '1' and params_address = C_WIDTH_ADDR else '0';
    w_strobe_height <= '1' when params_write = '1' and params_address = C_HEIGHT_ADDR else '0';

	WRITE_MM: process(clk) is
	begin
		if rising_edge(clk) then
            if w_strobe_sx = '1' then
                r_sx <= params_writedata(r_sx'range);
            end if;
            if w_strobe_sy = '1' then
                r_sy <= params_writedata(r_sy'range);
            end if;
            if w_strobe_sx_inv = '1' then
                r_sx_inv <= params_writedata;
            end if;
            if w_strobe_sy_inv = '1' then
                r_sy_inv <= params_writedata;
            end if;
            if w_strobe_width = '1' then
                r_width <= params_writedata;
            end if;
            if w_strobe_height = '1' then
                r_height <= params_writedata;
            end if;
            if (reset = '1') then
                r_sx <= (others => '0');
                r_sy <= (others => '0');
                r_sx_inv <= (others => '0');
                r_sy_inv <= (others => '0');
                r_width <= (others => '0');
                r_height <= (others => '0');
            end if;
		end if;
	end process WRITE_MM;

    process(params_address, r_sx, r_sy, r_sx_inv, r_sy_inv, r_width, r_height) is
	begin
        case params_address is
            when C_SX_ADDR      => w_read_mm(r_sx'range) <= r_sx;
            when C_SY_ADDR      => w_read_mm(r_sy'range) <= r_sy;
            when C_SX_INV_ADDR  => w_read_mm <= r_sx_inv;
            when C_SY_INV_ADDR  => w_read_mm <= r_sy_inv;
            when C_WIDTH_ADDR   => w_read_mm <= r_width;
            when C_HEIGHT_ADDR  => w_read_mm <= r_height;
            when others         => w_read_mm <= (others => '0');
        end case;
    end process;

	READ_MM: process(clk) is
	begin
		if rising_edge(clk) then
			params_readdata <= w_read_mm;
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
