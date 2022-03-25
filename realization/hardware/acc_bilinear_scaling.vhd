library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.acc_bilinear_scaling_PK.all;

entity acc_bilinear_scaling is
    port (
        clk                             : in  std_logic;
        reset                           : in  std_logic;
        asi_input_data_data             : in  std_logic_vector(C_DATA_WIDTH-1 downto 0);
        asi_input_data_valid            : in  std_logic;
        asi_input_data_ready            : out std_logic;
        asi_input_data_sop              : in  std_logic;
        asi_input_data_eop              : in  std_logic;
        aso_output_data_data            : out std_logic_vector(C_DATA_WIDTH-1 downto 0);
        aso_output_data_endofpacket     : out std_logic;
        aso_output_data_startofpacket   : out std_logic;
        aso_output_data_valid           : out std_logic;
        aso_output_data_ready           : in  std_logic;
        params_address                  : in  std_logic_vector(C_MM_ADDR_WIDTH-1 downto 0);
        params_read                     : in  std_logic;
        params_write                    : in  std_logic;
        params_readdata                 : out std_logic_vector(C_MM_DATA_WIDTH-1 downto 0);
        params_writedata                : in  std_logic_vector(C_MM_DATA_WIDTH-1 downto 0);
        params_waitrequest              : out std_logic
    );
end entity acc_bilinear_scaling;

architecture rtl of acc_bilinear_scaling is
    -- Arrays declared for RAM signals of both RAMs
    type ram_data_t     is array (0 to 1) of std_logic_vector(C_DATA_WIDTH-1 downto 0);
    type ram_addr_t     is array (0 to 1) of std_logic_vector(C_ADDR_WIDTH-1 downto 0);
    type ram_counter_t  is array (0 to 1) of integer range 0 to C_RAM_DEPTH-1;
    -- Register map array
    type register_map_t is array (0 to 2**C_MM_ADDR_WIDTH-1) of std_logic_vector(C_MM_DATA_WIDTH - 1 downto 0);
    -- Pixel group row data type
    type row_data_t     is array (0 to 1) of integer range 0 to 2**C_DATA_WIDTH-1;
    -- Declaring states for FSM
    type state_t        is (st_wait, st_read, st_process);

    -- State machine signals
    signal current_state    : state_t;
    signal next_state       : state_t;

    -- Component Avalaon MM registers
    signal register_map     : register_map_t;
    signal w_sx             : std_logic_vector(C_MM_DATA_WIDTH-1 downto 0);
    signal w_sy             : std_logic_vector(C_MM_DATA_WIDTH-1 downto 0);
    signal w_sx_inc         : std_logic_vector(2*C_MM_DATA_WIDTH-1 downto 0);
    signal w_sy_inc         : std_logic_vector(2*C_MM_DATA_WIDTH-1 downto 0);
    signal w_width          : std_logic_vector(2*C_MM_DATA_WIDTH-1 downto 0);
    signal w_height         : std_logic_vector(2*C_MM_DATA_WIDTH-1 downto 0);

    -- Output image dimensions
    signal r_width_out      : integer range 0 to 2**C_DIM_WIDTH;
    signal r_height_out     : integer range 0 to 2**C_DIM_WIDTH;

    -- Output image position counters
    signal c_x_out          : integer range 0 to 2**C_DIM_WIDTH;
    signal c_y_out          : integer range 0 to 2**C_DIM_WIDTH;

    -- Currently active RAM
    signal w_ram_sel        : std_logic;
    -- RAM filled statuses
    signal w_ram_filled     : std_logic_vector(1 downto 0);
    -- RAM reset statuses
    signal r_ram_reset      : std_logic_vector(1 downto 0);

    -- RAM read control signals
    signal w_ram_rd         : std_logic;
    signal w_ram_rd_addr    : std_logic_vector(C_ADDR_WIDTH-1 downto 0);
    signal c_ram_rd_addr    : integer range 0 to C_RAM_DEPTH-1;
    signal w_ram_data_out   : ram_data_t;

    -- Registers with pixel values needed for current calculation
    signal r_top            : row_data_t;
    signal r_bottom         : row_data_t;

    -- Computation signals
    signal r_alpha_x        : integer range 0 to 2**C_NFRAC-1;
    signal r_alpha_y        : integer range 0 to 2**C_NFRAC-1;
    signal r_floor_x        : integer range 0 to 2**C_DIM_WIDTH-1;
    signal r_floor_y        : integer range 0 to 2**C_DIM_WIDTH-1;
    signal r_floor_x1       : integer range 0 to 2**C_DIM_WIDTH-1;
    signal r_floor_y1       : integer range 0 to 2**C_DIM_WIDTH-1;

    -- Image coordinates signals
    signal r_x              : std_logic_vector(C_DIM_WIDTH+C_NFRAC-1 downto 0);
    signal r_y              : std_logic_vector(C_DIM_WIDTH+C_NFRAC-1 downto 0);
    signal w_x_inc          : integer range 0 to 2**(C_DIM_WIDTH+1)-1;
    signal w_floor_x_inc    : integer range 0 to 2**(C_DIM_WIDTH+1)-1;

    -- Flag indicating that all pixels that need current group of pixels
    -- are processed and new group of pixels can be read
    signal r_proc_flag      : std_logic;

    -- Informs about the read status of current pixel group
    signal r_read_status    : std_logic_vector(3 downto 0);
begin

    RAM_writer_i0: entity work.RAM_writer
        generic map (
            G_RAM_DATA_WIDTH => C_DATA_WIDTH,
            G_RAM_ADDR_WIDTH => C_ADDR_WIDTH
        )
        port map (
            clk => clk,
            reset => reset,
            asi_input_data_data => asi_input_data_data,
            asi_input_data_valid => asi_input_data_valid,
            asi_input_data_ready => asi_input_data_ready,
            asi_input_data_sop => asi_input_data_sop,
            asi_input_data_eop => asi_input_data_eop,
            rd => w_ram_rd,
            rd_addr => w_ram_rd_addr,
            row_length => w_width,
            data_out_0 => w_ram_data_out(0),
            data_out_1 => w_ram_data_out(1),
            ram_sel => w_ram_sel,
            ram_filled => w_ram_filled,
            ram_reset => r_ram_reset
        );

    -- Mapping signals from register map to meaningful names
    w_sx     <= register_map(C_SX_ADDR);
    w_sy     <= register_map(C_SY_ADDR);
    w_sx_inc <= register_map(C_SX_INV_ADDR+1) & register_map(C_SX_INV_ADDR);
    w_sy_inc <= register_map(C_SY_INV_ADDR+1) & register_map(C_SY_INV_ADDR);
    w_width  <= register_map(C_WIDTH_ADDR+1) & register_map(C_WIDTH_ADDR);
    w_height <= register_map(C_HEIGHT_ADDR+1) & register_map(C_HEIGHT_ADDR);

    -- Calculating alpha and floor values
    r_alpha_x <= to_integer(unsigned(r_x(C_NFRAC-1 downto 0)));
    r_alpha_y <= to_integer(unsigned(r_y(C_NFRAC-1 downto 0)));
    r_floor_x <= to_integer(unsigned(r_x(r_x'high downto C_NFRAC)));
    r_floor_y <= to_integer(unsigned(r_y(r_y'high downto C_NFRAC)));

    -- Sequential state change
    CONTROL_STATE: process(clk) is
    begin
        if rising_edge(clk) then
            current_state <= next_state;
            if reset='1' then
                current_state <= st_wait;
            end if;
        end if;
    end process CONTROL_STATE;

    -- Determines next state
    NEXT_STATE_PROCESS: process(current_state, r_proc_flag, w_ram_filled, r_read_status) is
    begin
        case current_state is
            when st_wait =>
                if w_ram_filled(0)='1' and w_ram_filled(1)='1' then
                    next_state <= st_read;
                else
                    next_state <= st_wait;
                end if;
            when st_read =>
                if r_read_status(0)='0' then
                    next_state <= st_read;
                else
                    next_state <= st_process;
                end if;
            when st_process =>
                if r_proc_flag = '0' then
                    next_state <= st_process;
                else
                    if c_x_out < r_width_out-1 then
                        next_state <= st_read;
                    else
                        next_state <= st_wait;
                    end if;
                end if;
            when others =>
                next_state <= st_wait;
        end case;
    end process NEXT_STATE_PROCESS;

    -- Main processing logic
    PROCESSING: process(clk) is
        variable v_x        : std_logic_vector(r_x'range);
        variable v_alpha_x  : integer range 0 to 2**C_NFRAC-1;
        variable v_floor_x  : integer range 0 to 2**C_DIM_WIDTH-1;
        variable v_x_out    : integer range 0 to 2**C_DIM_WIDTH-1;

        variable v_y        : std_logic_vector(r_y'range);
        variable v_alpha_y  : integer range 0 to 2**C_NFRAC-1;
        variable v_floor_y  : integer range 0 to 2**C_DIM_WIDTH-1;
        variable v_y_out    : integer range 0 to 2**C_DIM_WIDTH-1;

        variable v_width    : integer range 0 to 2**C_DIM_WIDTH;
        variable v_height   : integer range 0 to 2**C_DIM_WIDTH;
    begin
        if rising_edge(clk) then
            v_width  := to_integer(unsigned(w_width));
            v_height := to_integer(unsigned(w_height));
            if current_state = st_process then
                v_x := std_logic_vector(unsigned(r_x) + unsigned(w_sx_inc));
                v_alpha_x := to_integer(unsigned(v_x(C_NFRAC-1 downto 0)));
                v_floor_x := to_integer(unsigned(v_x(v_x'high downto C_NFRAC)));
                r_x <= v_x when (v_floor_x < v_width) else (others => '0');

                v_x_out := c_x_out + 1;
                c_x_out <= v_x_out when (v_x_out <= r_width_out-1) else 0;

                if c_x_out=r_width_out-1 then
                    v_y_out := c_y_out + 1;
                    c_y_out <= v_y_out when (v_y_out <= r_height_out-1) else 0;

                    v_y := std_logic_vector(unsigned(r_y) + unsigned(w_sy_inc));
                    v_alpha_y := to_integer(unsigned(v_y(C_NFRAC-1 downto 0)));
                    v_floor_y := to_integer(unsigned(v_y(v_y'high downto C_NFRAC)));
                    r_y <= v_y when (v_floor_y < v_height) else (others => '0');
                end if;

            end if;
            if reset='1' then
                r_x <= (others => '0');
                r_y <= (others => '0');
                c_x_out <= 0;
                c_y_out <= 0;
            end if;
        end if;
    end process PROCESSING;

    -- Generating r_proc_flag
    w_x_inc <= to_integer(unsigned(r_x)) + to_integer(unsigned(w_sx_inc));
    w_floor_x_inc <= w_x_inc / 2**C_NFRAC;
    r_proc_flag <= '1' when w_floor_x_inc>r_floor_x and current_state=st_process else '0';

    -- Generating RAM rd signal
    w_ram_rd <= '1' when current_state=st_read else '0';

    -- Generating RAM reset signals
    RAM_RESET_PROC: process(c_x_out, c_y_out, r_width_out, r_height_out, w_ram_sel) is
        variable v_ram_sel : integer range 0 to 1;
    begin
        v_ram_sel := 0 when w_ram_sel='0' else 1;
        if c_x_out = r_width_out-1 then
            if c_y_out = r_height_out-1 then
                r_ram_reset <= (others => '1');
            else
                r_ram_reset <= (others => '0');
            end if;
            r_ram_reset(v_ram_sel) <= '1';
        else
            r_ram_reset <= (others => '0');
        end if;
    end process RAM_RESET_PROC;

    -- TODO: this can be improved
    RAM_READ_ADDRESS: process(current_state, r_read_status, r_floor_x) is
        variable v_width    : integer range 0 to 2**(2*C_MM_DATA_WIDTH) - 1;
        variable v_height   : integer range 0 to 2**(2*C_MM_DATA_WIDTH) - 1;
    begin
        if current_state = st_read then
            v_width := to_integer(unsigned(w_width));
            v_height := to_integer(unsigned(w_height));
            case r_read_status is
                when "1000" =>
                    c_ram_rd_addr <= r_floor_x;
                when "0100" =>
                    c_ram_rd_addr <= r_floor_x;
                when "0010" =>
                    if r_floor_x=v_width-1 then
                        c_ram_rd_addr <= r_floor_x;
                    else
                        c_ram_rd_addr <= r_floor_x + 1;
                    end if;
                when "0001" =>
                    -- If at the end of the row, saturate
                    if r_floor_x=v_width-1 then
                        c_ram_rd_addr <= r_floor_x;
                    else
                        c_ram_rd_addr <= r_floor_x + 1;
                    end if;
                when others =>
                    c_ram_rd_addr <= r_floor_x;
            end case;
        end if;
    end process RAM_READ_ADDRESS;
    w_ram_rd_addr <= std_logic_vector(to_unsigned(c_ram_rd_addr, C_ADDR_WIDTH));

    -- TODO: this can be improved
    READ_DATA_BUFFERS: process(clk) is
        variable v_sel_top      : integer range 0 to 1;
        variable v_sel_bottom   : integer range 0 to 1;
        variable v_ram_sel      : integer range 0 to 1;
    begin
        if rising_edge(clk) then
            v_sel_bottom := 1 when v_ram_sel=0 else 0;
            v_sel_top    := 0 when v_ram_sel=0 else 1;
            v_ram_sel    := 0 when w_ram_sel='0' else 1;
            if current_state = st_read then
                case r_read_status is
                    when "1000" =>
                        null;
                    when "0100" =>
                        r_top(0)    <= to_integer(unsigned(w_ram_data_out(v_sel_top)));
                        r_bottom(0) <= to_integer(unsigned(w_ram_data_out(v_sel_bottom)));
                    when "0010" =>
                        null;
                    when "0001" =>
                        r_top(1)    <= to_integer(unsigned(w_ram_data_out(v_sel_top)));
                        r_bottom(1) <= to_integer(unsigned(w_ram_data_out(v_sel_bottom)));
                    when others =>
                        null;
                end case;
                r_read_status <= r_read_status(0) & r_read_status(3 downto 1);
            end if;
            if reset='1' then
                r_top <= (others => 0);
                r_bottom <= (others => 0);
                r_read_status <= "1000";
            end if;
        end if;
    end process READ_DATA_BUFFERS;

    OUTPUT_DIMS_CALC: process(clk) is
        variable v_sx       : integer range 0 to 2**C_MM_DATA_WIDTH - 1;
        variable v_sy       : integer range 0 to 2**C_MM_DATA_WIDTH - 1;
        variable v_width    : integer range 0 to 2**(2*C_MM_DATA_WIDTH) - 1;
        variable v_height   : integer range 0 to 2**(2*C_MM_DATA_WIDTH) - 1;
    begin
        if rising_edge(clk) then
            v_width := to_integer(unsigned(w_width));
            v_sx := to_integer(unsigned(w_sx));

            r_width_out <= (v_width * v_sx) / 2**5;

            v_height := to_integer(unsigned(w_height));
            v_sy := to_integer(unsigned(w_sy));

            r_height_out <= (v_height * v_sy) / 2**5;
        end if;
    end process OUTPUT_DIMS_CALC;

    -- Avalon MM write implementation
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

    -- Avalon MM write implementation
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

    params_waitrequest <= '0';

    -- TODO: Auto-generated HDL template

    aso_output_data_data <= "00000000";

    aso_output_data_startofpacket <= '0';

    aso_output_data_endofpacket <= '0';

end architecture rtl; -- of acc_bilinear_scaling
