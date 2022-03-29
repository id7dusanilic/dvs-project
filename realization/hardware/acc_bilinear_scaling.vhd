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
    -- Amount of delay from the start of calculation to ASO output
    constant C_VALID_DELAY  : natural := 3;

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
    signal w_x_inc          : std_logic_vector(2*C_MM_DATA_WIDTH-1 downto 0);
    signal w_y_inc          : std_logic_vector(2*C_MM_DATA_WIDTH-1 downto 0);
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
    -- Number of rows written by RAM_writer
    signal w_row_cnt        : std_logic_vector(C_DIM_WIDTH-1 downto 0);
    -- Reset row count
    signal r_reset_row_cnt  : std_logic;

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

    signal r_alpha_y_d1     : integer range 0 to 2**C_NFRAC-1;

    -- Image coordinates signals
    signal r_x              : std_logic_vector(C_DIM_WIDTH+C_NFRAC-1 downto 0);
    signal r_y              : std_logic_vector(C_DIM_WIDTH+C_NFRAC-1 downto 0);
    signal w_x_incremented  : integer range 0 to 2**(C_DIM_WIDTH+C_NFRAC+1)-1;
    signal w_y_incremented  : integer range 0 to 2**(C_DIM_WIDTH+C_NFRAC+1)-1;
    signal w_floor_x_incremented    : integer range 0 to 2**(C_DIM_WIDTH+C_NFRAC+1)-1;
    signal w_floor_y_incremented    : integer range 0 to 2**(C_DIM_WIDTH+C_NFRAC+1)-1;

    -- Calculation subproducts
    signal r_subp_topleft   : integer range 0 to 2**(C_NFRAC+C_DATA_WIDTH)-1;
    signal r_subp_botleft   : integer range 0 to 2**(C_NFRAC+C_DATA_WIDTH)-1;
    signal r_subp_topright  : integer range 0 to 2**(C_NFRAC+C_DATA_WIDTH)-1;
    signal r_subp_botright  : integer range 0 to 2**(C_NFRAC+C_DATA_WIDTH)-1;
    signal r_subp_top       : integer range 0 to 2**(C_NFRAC+C_DATA_WIDTH)-1;
    signal r_subp_bot       : integer range 0 to 2**(C_NFRAC+C_DATA_WIDTH)-1;
    signal r_prod           : std_logic_vector(C_DATA_WIDTH-1 downto 0);

    -- Avalon Stream handshake delayed signals
    signal r_valid          : std_logic_vector(C_VALID_DELAY-1 downto 0);
    signal r_last           : std_logic_vector(C_VALID_DELAY-1 downto 0);
    signal r_sop            : std_logic_vector(C_VALID_DELAY-1 downto 0);

    -- Flag indicating that all pixels that need current group of pixels
    -- are processed and new group of pixels can be read
    signal w_proc_flag      : std_logic;
    signal w_need_new_row   : std_logic;

    -- Informs about the read status of current pixel group
    signal r_read_status    : std_logic_vector(2 downto 0);
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
            data_out_0 => w_ram_data_out(0),
            data_out_1 => w_ram_data_out(1),
            ram_sel => w_ram_sel,
            ram_filled => w_ram_filled,
            reset_row_count => r_reset_row_cnt,
            row_count => w_row_cnt,
            ram_reset => r_ram_reset
        );

    -- Mapping signals from register map to meaningful names
    w_sx     <= register_map(C_SX_ADDR);
    w_sy     <= register_map(C_SY_ADDR);
    w_x_inc  <= register_map(C_X_INC_ADDR+1) & register_map(C_X_INC_ADDR);
    w_y_inc  <= register_map(C_Y_INC_ADDR+1) & register_map(C_Y_INC_ADDR);
    w_width  <= register_map(C_WIDTH_ADDR+1) & register_map(C_WIDTH_ADDR);
    w_height <= register_map(C_HEIGHT_ADDR+1) & register_map(C_HEIGHT_ADDR);

    -- Calculating alpha and floor values
    r_alpha_x <= to_integer(unsigned(r_x(C_NFRAC-1 downto 0)));
    r_alpha_y <= to_integer(unsigned(r_y(C_NFRAC-1 downto 0)));
    r_floor_x <= to_integer(unsigned(r_x(r_x'high downto C_NFRAC)));
    r_floor_y <= to_integer(unsigned(r_y(r_y'high downto C_NFRAC)));

    -- Avalon Stream handshake signals
    aso_output_data_data <= r_prod;
    aso_output_data_valid <= r_valid(0);
    aso_output_data_endofpacket <= r_last(0);
    aso_output_data_startofpacket <= r_sop(0);

    -- Sequential state change
    CONTROL_STATE: process(clk) is
    begin
        if rising_edge(clk) then
            current_state <= next_state;
            if reset = '1' then
                current_state <= st_wait;
            end if;
        end if;
    end process CONTROL_STATE;

    -- Determines next state
    NEXT_STATE_PROCESS: process(current_state, w_proc_flag, w_ram_filled, r_read_status) is
    begin
        case current_state is
            when st_wait =>
                if w_ram_filled(0) = '1' and w_ram_filled(1) = '1' then
                    next_state <= st_read;
                else
                    next_state <= st_wait;
                end if;
            when st_read =>
                if r_read_status(0) = '0' then
                    next_state <= st_read;
                else
                    next_state <= st_process;
                end if;
            when st_process =>
                if w_proc_flag = '0' then
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

        variable v_top      : row_data_t;
        variable v_bottom   : row_data_t;
    begin
        if rising_edge(clk) then
            v_width  := to_integer(unsigned(w_width));
            v_height := to_integer(unsigned(w_height));

            -- Variables initialized to current values because they're used for determining v_top and v_bottom
            v_x := std_logic_vector(unsigned(r_x));
            v_floor_x := to_integer(unsigned(v_x(v_x'high downto C_NFRAC)));
            v_y := std_logic_vector(unsigned(r_y));
            v_floor_y := to_integer(unsigned(v_y(v_y'high downto C_NFRAC)));

            if aso_output_data_ready = '1' then
                r_valid <= '0' & r_valid(r_valid'high downto 1);
                r_last <= '0' & r_last(r_last'high downto 1);
                r_sop <= '0' & r_sop(r_sop'high downto 1);

                if current_state = st_process then
                    v_x := std_logic_vector(unsigned(r_x) + unsigned(w_x_inc));
                    v_alpha_x := to_integer(unsigned(v_x(C_NFRAC-1 downto 0)));
                    v_floor_x := to_integer(unsigned(v_x(v_x'high downto C_NFRAC)));
                    if (v_floor_x < v_width and c_x_out/=r_width_out-1) then
                        r_x <= v_x;
                    else
                        r_x <= (others => '0');
                    end if;

                    v_x_out := c_x_out + 1;
                    if (v_x_out <= r_width_out-1) then
                        c_x_out <= v_x_out;
                    else
                        c_x_out <= 0;
                    end if;

                    if c_x_out = r_width_out-1 then
                        v_y := std_logic_vector(unsigned(r_y) + unsigned(w_y_inc));
                        v_alpha_y := to_integer(unsigned(v_y(C_NFRAC-1 downto 0)));
                        v_floor_y := to_integer(unsigned(v_y(v_y'high downto C_NFRAC)));
                        if (v_floor_y < v_height and c_y_out/=r_height_out-1) then
                            r_y <= v_y;
                        else
                            r_y <= (others => '0');
                        end if;

                        v_y_out := c_y_out + 1;
                        if (v_y_out <= r_height_out-1) then
                            c_y_out <= v_y_out;
                        else
                            c_y_out <= 0;
                        end if;
                    end if;

                    if v_floor_y /= v_height-1 then
                        v_top := r_top;
                    else
                        v_top := r_bottom;
                    end if;
                    v_bottom := r_bottom;

                    r_subp_topleft <= (2**C_NFRAC - r_alpha_x) * v_top(0);
                    r_subp_botleft <= (2**C_NFRAC - r_alpha_x) * v_bottom(0);
                    r_subp_topright <= r_alpha_x * v_top(1);
                    r_subp_botright <= r_alpha_x * v_bottom(1);

                    r_valid <= '1' & r_valid(r_valid'high downto 1);
                    if c_x_out = r_width_out-1 then
                        r_last <= '1' & r_last(r_last'high downto 1);
                    end if;
                    if c_x_out = 0 then
                        r_sop <= '1' & r_sop(r_sop'high downto 1);
                    end if;
                end if;

                r_subp_top <= (2**C_NFRAC - r_alpha_y_d1) * ((r_subp_topleft + r_subp_topright) / 2**C_NFRAC);
                r_subp_bot <= r_alpha_y_d1 * ((r_subp_botleft + r_subp_botright) / 2**C_NFRAC);

                r_alpha_y_d1 <= r_alpha_y;

                r_prod <= std_logic_vector(to_unsigned((r_subp_top + r_subp_bot) / 2**C_NFRAC, C_DATA_WIDTH));
            end if;
            if reset = '1' then
                r_subp_topleft <= 0;
                r_subp_botleft <= 0;
                r_subp_topright <= 0;
                r_subp_botright <= 0;
                r_subp_top <= 0;
                r_subp_bot <= 0;
                r_prod <= (others => '0');
                r_valid <= (others => '0');
                r_x <= (others => '0');
                r_y <= (others => '0');
                c_x_out <= 0;
                c_y_out <= 0;
            end if;
        end if;
    end process PROCESSING;

    -- Future coordinate values
    w_x_incremented <= to_integer(unsigned(r_x)) + to_integer(unsigned(w_x_inc));
    w_y_incremented <= to_integer(unsigned(r_y)) + to_integer(unsigned(w_y_inc));
    w_floor_x_incremented <= w_x_incremented / 2**C_NFRAC;
    w_floor_y_incremented <= w_y_incremented / 2**C_NFRAC;

    -- Generating w_proc_flag
    -- Current group of pixels is processed current state is st_process and new pixel is needed
    -- and the output was ready so the pipeline moved
    w_proc_flag <= '1' when (w_floor_x_incremented > r_floor_x or c_x_out = r_width_out-1) and current_state = st_process and aso_output_data_ready = '1' else '0';

    -- New row is needed when next floor y value is greater the current, but only if the next floor y value
    -- is in the range (not greater than image height)
    w_need_new_row <= '1' when
        (c_x_out = r_width_out-1
        and w_floor_y_incremented > r_floor_y
        and w_floor_y_incremented < to_integer(unsigned(w_height))-1)
        or r_floor_y > to_integer(unsigned(w_row_cnt))
        else '0';

    -- This process makes sure that all input rows are read, even if they are not
    -- used for calculation (This is neccessary at the end of the image in case of
    -- downscaling.
    FLUSH_PROCESS: process (clk) is
        variable v_height   : integer range 0 to 2**(2*C_MM_DATA_WIDTH) - 1;
        variable v_row_cnt  : integer range 0 to 2**C_DIM_WIDTH - 1;
    begin
        if rising_edge(clk) then
            v_height := to_integer(unsigned(w_height));
            v_row_cnt := to_integer(unsigned(w_row_cnt));

            r_reset_row_cnt <= '0';

            -- Set when at the end of image
            if c_x_out = r_width_out-1 and c_y_out = r_height_out-1 then
                r_flush <= '1';
                -- Now it's safe to reset row count of the RAM_writer
                r_reset_row_cnt <= '1';
            end if;

            -- Reset when all input pixels are written
            if v_row_cnt = v_height then
                r_flush <= '0';
            end if;

            if reset = '1' then
                r_flush <= '0';
                r_reset_row_cnt <= '0';
            end if;
        end if;
    end process FLUSH_PROCESS;


    -- Generating RAM rd signal
    w_ram_rd <= '1' when current_state = st_read else '0';

    -- Generating RAM reset signals
    RAM_RESET_PROC: process(c_x_out, c_y_out, r_width_out, r_height_out, w_need_new_row, w_ram_sel, r_flush) is
        variable v_ram_sel  : integer range 0 to 1;
        variable v_height   : integer range 0 to 2**(2*C_MM_DATA_WIDTH) - 1;
    begin
        v_height := to_integer(unsigned(w_height));
        if w_ram_sel = '0' then
            v_ram_sel := 0;
        else
            v_ram_sel := 1;
        end if;
        -- Default value
        r_ram_reset <= (others => '0');

        -- If at the end of row and new row is needed for computation
        if w_need_new_row = '1' then
            r_ram_reset(v_ram_sel) <= '1';
        -- If last input rows need to be flushed
        elsif r_flush = '1' then
            r_ram_reset <= (others => '1');
        -- If at the end of processing
        elsif c_x_out = r_width_out-1 and c_y_out = r_height_out-1 then
            r_ram_reset <= (others => '1');
        else
            r_ram_reset <= (others => '0');
        end if;
    end process RAM_RESET_PROC;

    RAM_READ_ADDRESS: process(current_state, r_read_status, r_floor_x) is
        variable v_width    : integer range 0 to 2**(2*C_MM_DATA_WIDTH) - 1;
    begin
        if current_state = st_read then
            v_width := to_integer(unsigned(w_width));
            case r_read_status is
                when "100" =>
                    c_ram_rd_addr <= r_floor_x;
                when "010" =>
                    if r_floor_x = v_width-1 then
                        c_ram_rd_addr <= r_floor_x;
                    else
                        c_ram_rd_addr <= r_floor_x + 1;
                    end if;
                when "001" =>
                    -- If at the end of the row, saturate
                    if r_floor_x = v_width-1 then
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

    READ_DATA_BUFFERS: process(clk) is
        variable v_sel_top      : integer range 0 to 1;
        variable v_sel_bottom   : integer range 0 to 1;
        variable v_ram_sel      : integer range 0 to 1;
    begin
        if rising_edge(clk) then
            if w_ram_sel = '0' then
                v_ram_sel := 0;
            else
                v_ram_sel := 1;
            end if;

            if v_ram_sel = 0 then
                v_sel_top := 0;
                v_sel_bottom := 1;
            else
                v_sel_top := 1;
                v_sel_bottom := 0;
            end if;

            if current_state = st_read then
                case r_read_status is
                    when "100" =>
                        null;
                    when "010" =>
                        r_top(0)    <= to_integer(unsigned(w_ram_data_out(v_sel_top)));
                        r_bottom(0) <= to_integer(unsigned(w_ram_data_out(v_sel_bottom)));
                    when "001" =>
                        r_top(1)    <= to_integer(unsigned(w_ram_data_out(v_sel_top)));
                        r_bottom(1) <= to_integer(unsigned(w_ram_data_out(v_sel_bottom)));
                    when others =>
                        null;
                end case;
                r_read_status <= r_read_status(0) & r_read_status(r_read_status'high downto 1);
            end if;
            if reset = '1' then
                r_top <= (others => 0);
                r_bottom <= (others => 0);
                r_read_status <= (r_read_status'high => '1', others => '0');
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

            r_width_out <= (v_width * v_sx) / 2**C_SCALE_FRAC;

            v_height := to_integer(unsigned(w_height));
            v_sy := to_integer(unsigned(w_sy));

            r_height_out <= (v_height * v_sy) / 2**C_SCALE_FRAC;
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

end architecture rtl; -- of acc_bilinear_scaling
