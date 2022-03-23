library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.acc_bilinear_scaling_PK.all;

entity acc_bilinear_scaling is
    port (
        clk                             : in  std_logic := '0';
        reset                           : in  std_logic := '0';
        asi_input_data_data             : in  std_logic_vector(C_DATA_WIDTH-1 downto 0) := (others => '0');
        asi_input_data_valid            : in  std_logic := '0';
        asi_input_data_ready            : out std_logic;
        asi_input_data_sop              : in  std_logic := '0';
        asi_input_data_eop              : in  std_logic := '0';
        aso_output_data_data            : out std_logic_vector(C_DATA_WIDTH-1 downto 0);
        aso_output_data_endofpacket     : out std_logic;
        aso_output_data_startofpacket   : out std_logic;
        aso_output_data_valid           : out std_logic;
        aso_output_data_ready           : in  std_logic := '0';
        params_address                  : in  std_logic_vector(C_MM_ADDR_WIDTH-1 downto 0) := (others => '0');
        params_read                     : in  std_logic := '0';
        params_write                    : in  std_logic := '0';
        params_readdata                 : out std_logic_vector(C_MM_DATA_WIDTH-1 downto 0);
        params_writedata                : in  std_logic_vector(C_MM_DATA_WIDTH-1 downto 0) := (others => '0');
        params_waitrequest              : out std_logic
    );
end entity acc_bilinear_scaling;

architecture rtl of acc_bilinear_scaling is
    type ram_signal_t   is array (0 to 1) of std_logic;
    type ram_data_t     is array (0 to 1) of std_logic_vector(C_DATA_WIDTH-1 downto 0);
    type ram_addr_t     is array (0 to 1) of std_logic_vector(C_ADDR_WIDTH-1 downto 0);
    type ram_counter_t  is array (0 to 1) of integer range 0 to C_RAM_DEPTH-1;
    type register_map_t is array (0 to 2**C_MM_ADDR_WIDTH-1) of std_logic_vector(C_MM_DATA_WIDTH - 1 downto 0);

    type row_data_t     is array (0 to 1) of integer range 0 to 2**C_DATA_WIDTH-1;

    type state_t        is (st_wait, st_read, st_process);

    signal current_state    : state_t;
    signal next_state       : state_t;

    signal register_map     : register_map_t;

    signal r_sx             : std_logic_vector(C_MM_DATA_WIDTH-1 downto 0);
    signal r_sy             : std_logic_vector(C_MM_DATA_WIDTH-1 downto 0);
    signal r_sx_inv         : std_logic_vector(2*C_MM_DATA_WIDTH-1 downto 0);
    signal r_sy_inv         : std_logic_vector(2*C_MM_DATA_WIDTH-1 downto 0);
    signal r_width          : std_logic_vector(2*C_MM_DATA_WIDTH-1 downto 0);
    signal r_height         : std_logic_vector(2*C_MM_DATA_WIDTH-1 downto 0);

    signal w_width          : integer range 0 to 2**C_DIM_WIDTH;
    signal w_height         : integer range 0 to 2**C_DIM_WIDTH;

    signal r_width_out      : integer range 0 to 2**C_DIM_WIDTH;
    signal r_height_out     : integer range 0 to 2**C_DIM_WIDTH;

    signal c_x_out          : integer range 0 to 2**C_DIM_WIDTH;
    signal c_y_out          : integer range 0 to 2**C_DIM_WIDTH;

    signal r_ram_sel        : std_logic; -- The RAM that is being written to
    signal w_ram_sel        : integer range 0 to 1;

    signal r_rd             : std_logic;
    signal w_wr_array       : ram_signal_t;
    signal c_wr_column      : ram_counter_t;
    signal w_wr_addr        : ram_addr_t;

    signal c_rd_column      : integer range 0 to C_RAM_DEPTH-1;
    signal w_rd_addr        : std_logic_vector(C_ADDR_WIDTH-1 downto 0);

    signal r_data_in        : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal r_data_out       : ram_data_t;

    signal r_ram_filled     : ram_signal_t;
    signal w_processing     : std_logic;
    signal r_wr             : std_logic;

    signal w_asi_input_data_ready : std_logic;

    signal r_x              : std_logic_vector(C_DIM_WIDTH+C_NFRAC-1 downto 0);
    signal r_y              : std_logic_vector(C_DIM_WIDTH+C_NFRAC-1 downto 0);
    signal r_alpha_x        : integer range 0 to 2**C_NFRAC-1;
    signal r_alpha_y        : integer range 0 to 2**C_NFRAC-1;
    signal r_floor_x        : integer range 0 to 2**C_DIM_WIDTH-1;
    signal r_floor_y        : integer range 0 to 2**C_DIM_WIDTH-1;
    signal r_floor_x1       : integer range 0 to 2**C_DIM_WIDTH-1;
    signal r_floor_y1       : integer range 0 to 2**C_DIM_WIDTH-1;

    signal w_x_inc          : integer range 0 to 2**(C_DIM_WIDTH+1)-1;
    signal w_floor_x_inc    : integer range 0 to 2**(C_DIM_WIDTH+1)-1;

    signal r_top            : row_data_t;
    signal r_bottom         : row_data_t;

    signal r_proc_flag      : std_logic;

    signal r_read_status    : std_logic_vector(3 downto 0);
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

    r_alpha_x <= to_integer(unsigned( r_x(C_NFRAC-1 downto 0) ));
    r_alpha_y <= to_integer(unsigned( r_y(C_NFRAC-1 downto 0) ));
    r_floor_x <= to_integer(unsigned( r_x(r_x'high downto C_NFRAC)));
    r_floor_y <= to_integer(unsigned( r_y(r_y'high downto C_NFRAC)));

    w_x_inc <= to_integer(unsigned(r_x)) + to_integer(unsigned(r_sx_inv));
    w_floor_x_inc <= w_x_inc / 2**C_NFRAC;

    r_proc_flag <= '1' when w_floor_x_inc>r_floor_x and current_state=st_process else '0';

    CONTROL_STATE: process(clk) is
    begin
        if rising_edge(clk) then
            current_state <= next_state;
            if reset='1' then
                current_state <= st_wait;
            end if;
        end if;
    end process CONTROL_STATE;

    NEXT_STATE_PROCESS: process(current_state, r_proc_flag, r_ram_filled, r_read_status) is
    begin
        case current_state is
            when st_wait =>
                if r_ram_filled(0)='1' and r_ram_filled(1)='1' then
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

    OUTPUT_GENERATE: process(current_state) is
    begin
        case current_state is
            when st_read =>
                r_rd <= '1';
            when others =>
                r_rd <= '0';
        end case;
    end process OUTPUT_GENERATE;

    PROCESSING: process(clk) is
        variable v_x : std_logic_vector(r_x'range);
        variable v_alpha_x : integer range 0 to 2**C_NFRAC-1;
        variable v_floor_x : integer range 0 to 2**C_DIM_WIDTH-1;
        variable v_x_out   : integer range 0 to 2**C_DIM_WIDTH-1;

        variable v_y : std_logic_vector(r_y'range);
        variable v_alpha_y : integer range 0 to 2**C_NFRAC-1;
        variable v_floor_y : integer range 0 to 2**C_DIM_WIDTH-1;
        variable v_y_out   : integer range 0 to 2**C_DIM_WIDTH-1;
    begin
        if rising_edge(clk) then
            if current_state = st_process then
                v_x := std_logic_vector(unsigned(r_x) + unsigned(r_sx_inv));
                v_alpha_x := to_integer(unsigned(v_x(C_NFRAC-1 downto 0)));
                v_floor_x := to_integer(unsigned(v_x(v_x'high downto C_NFRAC)));
                r_x <= v_x when (v_floor_x < w_width) else (others => '0');

                v_y := std_logic_vector(unsigned(r_y) + unsigned(r_sy_inv));
                v_alpha_y := to_integer(unsigned(v_y(C_NFRAC-1 downto 0)));
                v_floor_y := to_integer(unsigned(v_y(v_y'high downto C_NFRAC)));
                r_y <= v_y when (v_floor_y < w_height) else (others => '0');

                v_x_out := c_x_out + 1;
                c_x_out <= v_x_out when (v_x_out <= r_width_out-1) else 0;

                if c_x_out=r_width_out-1 then
                    v_y_out := c_y_out + 1;
                    c_y_out <= v_y_out when (v_y_out <= r_height_out-1) else 0;
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

    COL_SELECT: process(current_state, r_read_status, r_floor_x) is
    begin
        if current_state = st_read then
            case r_read_status is
                when "1000" =>
                    c_rd_column <= r_floor_x;
                when "0100" =>
                    c_rd_column <= r_floor_x;
                when "0010" =>
                    if r_floor_x=w_width-1 then
                        c_rd_column <= r_floor_x;
                    else
                        c_rd_column <= r_floor_x + 1;
                    end if;
                when "0001" =>
                    if r_floor_x=w_width-1 then
                        c_rd_column <= r_floor_x;
                    else
                        c_rd_column <= r_floor_x + 1;
                    end if;
                when others =>
                    c_rd_column <= r_floor_x;
            end case;
        end if;
    end process COL_SELECT;

    READ_DATA_BUFFERS: process(clk) is
    variable v_sel_top      : integer range 0 to 1;
    variable v_sel_bottom   : integer range 0 to 1;
    begin
        if rising_edge(clk) then
            v_sel_bottom := 1 when w_ram_sel=0 else 0;
            v_sel_top := 0 when w_ram_sel=0 else 1;
            if current_state = st_read then
                case r_read_status is
                    when "1000" =>
                        null;
                    when "0100" =>
                        r_top(0)    <= to_integer(unsigned(r_data_out(v_sel_top)));
                        r_bottom(0) <= to_integer(unsigned(r_data_out(v_sel_bottom)));
                    when "0010" =>
                        null;
                    when "0001" =>
                        r_top(1)    <= to_integer(unsigned(r_data_out(v_sel_top)));
                        r_bottom(1) <= to_integer(unsigned(r_data_out(v_sel_bottom)));
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

    w_wr_array(0) <= r_wr and not r_ram_filled(0) and not r_ram_sel;
    w_wr_array(1) <= r_wr and not r_ram_filled(1) and r_ram_sel;

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

            if c_x_out = r_width_out-1 then
                r_ram_filled(w_ram_sel) <= '0';

                if c_y_out = r_height_out-1 then
                    r_ram_filled <= (others => '0');
                end if;
            end if;

            if reset='1' then
                c_wr_column(0) <= 0;
                c_wr_column(1) <= 0;
                r_ram_filled <= (others => '0');
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

    r_data_in <= asi_input_data_data;
    r_wr <= (asi_input_data_valid and w_asi_input_data_ready);

    -- TODO: Auto-generated HDL template

    aso_output_data_data <= "00000000";

    aso_output_data_startofpacket <= '0';

    aso_output_data_endofpacket <= '0';

    params_waitrequest <= '0';

end architecture rtl; -- of acc_bilinear_scaling
