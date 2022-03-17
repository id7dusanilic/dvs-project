library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.acc_bilinear_scaling_PK.all;

entity acc_bilinear_scaling is
	port (
		clk                           : in  std_logic                     := '0';             --            clk.clk
		reset                         : in  std_logic                     := '0';             --          reset.reset
		asi_input_data_data           : in  std_logic_vector(C_DATA_WIDTH-1 downto 0)  := (others => '0'); --     input_data.data
		asi_input_data_valid          : in  std_logic                     := '0';             --               .valid
		asi_input_data_ready          : out std_logic;                                        --               .ready
		asi_input_data_sop            : in  std_logic                     := '0';             --               .startofpacket
		asi_input_data_eop            : in  std_logic                     := '0';             --               .endofpacket
		aso_output_data_data          : out std_logic_vector(C_DATA_WIDTH-1 downto 0);                     --    output_data.data
		aso_output_data_endofpacket   : out std_logic;                                        --               .endofpacket
		aso_output_data_startofpacket : out std_logic;                                        --               .startofpacket
		aso_output_data_valid         : out std_logic;                                        --               .valid
		aso_output_data_ready         : in  std_logic                     := '0';             --               .ready
		params_address                : in  std_logic_vector(2 downto 0)  := (others => '0'); -- scaling_coeffs.address
		params_read                   : in  std_logic                     := '0';             --               .read
		params_write                  : in  std_logic                     := '0';             --               .write
		params_readdata               : out std_logic_vector(C_DIM_WIDTH-1 downto 0);                    --               .readdata
		params_writedata              : in  std_logic_vector(C_DIM_WIDTH-1 downto 0) := (others => '0'); --               .writedata
		params_waitrequest            : out std_logic                                         --               .waitrequest
	);
end entity acc_bilinear_scaling;

architecture rtl of acc_bilinear_scaling is
signal r_sx         : std_logic_vector(C_SCALE_WIDTH-1 downto 0);
signal r_sy         : std_logic_vector(C_SCALE_WIDTH-1 downto 0);
signal r_sx_inv     : std_logic_vector(C_SCALE_INV_WIDTH-1 downto 0) := (0 => '1', others => '0');
signal r_sy_inv     : std_logic_vector(C_SCALE_INV_WIDTH-1 downto 0) := (0 => '1', others => '0');
signal r_width      : std_logic_vector(C_DIM_WIDTH-1 downto 0);
signal r_height     : std_logic_vector(C_DIM_WIDTH-1 downto 0);

signal w_width      : integer range 0 to 2**C_DIM_WIDTH;
signal w_height     : integer range 0 to 2**C_DIM_WIDTH;

type ram_signal_t is array (integer range 0 to 1) of std_logic;
type ram_data_t is array (integer range 0 to 1) of std_logic_vector (C_DATA_WIDTH-1 downto 0);
type ram_addr_t is array (integer range 0 to 1) of std_logic_vector (C_ADDR_WIDTH-1 downto 0);
type ram_counter_t is array (integer range 0 to 1) of integer range 0 to C_RAM_DEPTH-1;

signal r_ram_sel : std_logic := '0'; -- The RAM that is being written to
signal w_ram_sel : integer range 0 to 1;

signal r_rd         : std_logic := '0';
signal w_wr_array   : ram_signal_t := (others => '0');
signal c_column    : ram_counter_t := (others => 0);
signal w_wr_addr_array    : ram_addr_t := (others => (others => '0'));

signal c_rd_addr    : integer range 0 to C_RAM_DEPTH-1 := 0;
signal w_rd_addr    : std_logic_vector (C_ADDR_WIDTH-1 downto 0) := (others => '0');

signal r_data_in    : std_logic_vector (C_DATA_WIDTH-1 downto 0) := (others => '0');
signal r_data_out_array   : ram_data_t := (others => (others => '0'));

signal w_asi_input_data_ready : std_logic := '0';

begin

w_width <= to_integer(unsigned(r_width));
w_height <= to_integer(unsigned(r_height));

w_ram_sel <= 1 when r_ram_sel='1' else 0;

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
        wr_addr => w_wr_addr_array(0),
        data_in => r_data_in,
        data_out => r_data_out_array(0)
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
        wr_addr => w_wr_addr_array(1),
        data_in => r_data_in,
        data_out => r_data_out_array(1)
    );

w_wr_addr_array(0) <= std_logic_vector(to_unsigned(c_column(0), C_ADDR_WIDTH));
w_wr_addr_array(1) <= std_logic_vector(to_unsigned(c_column(1), C_ADDR_WIDTH));

w_asi_input_data_ready <= '1';
asi_input_data_ready <= w_asi_input_data_ready;

r_rd <= '1' when (c_column(0)>c_rd_addr and c_column(1)>c_rd_addr) else '0';

DATA_READ: process (clk) is
begin
    if rising_edge(clk) then
        if r_rd='1' then
            c_rd_addr <= c_rd_addr + 1;
            if c_rd_addr=w_width-1 then
                c_rd_addr <= 0;
            end if;
        end if;
    end if;
end process DATA_READ;

COUNT: process (clk) is
begin
    if rising_edge(clk) then
        if w_wr_array(w_ram_sel)='1' then
            c_column(w_ram_sel) <= c_column(w_ram_sel) + 1;
            if c_column(w_ram_sel) = w_width-1 then
                c_column(w_ram_sel) <= 0;
            end if;
        end if;
        if reset='1' then
            c_column(0) <= 0;
            c_column(1) <= 0;
        end if;
    end if;
end process COUNT;

RAM_SELECT: process (clk) is
begin
    if rising_edge(clk) then
        if c_column(w_ram_sel) = w_width-1 and w_wr_array(w_ram_sel)='1' then
            r_ram_sel <= not r_ram_sel;
        end if;
        if reset='1' then
            r_ram_sel <= '0';
        end if;
    end if;
end process RAM_SELECT;

r_data_in <= asi_input_data_data;
w_wr_array(0) <= (asi_input_data_valid and w_asi_input_data_ready) and not r_ram_sel;
w_wr_array(1) <= (asi_input_data_valid and w_asi_input_data_ready) and r_ram_sel;

-- TODO: Auto-generated HDL template

aso_output_data_data <= "00000000";

aso_output_data_startofpacket <= '0';

aso_output_data_endofpacket <= '0';

params_readdata <= "0000000000000000";

params_waitrequest <= '0';

end architecture rtl; -- of acc_bilinear_scaling
