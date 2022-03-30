library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

use work.acc_bilinear_scaling_PK.all;

entity acc_bilinear_scaling_TB is

end entity acc_bilinear_scaling_TB;

architecture Test of acc_bilinear_scaling_TB is
    signal clk : std_logic := '0';
    signal reset : std_logic := '1';
    signal asi_input_data_data : std_logic_vector (7 downto 0) := (others => '0');
    signal asi_input_data_valid : std_logic := '0';
    signal asi_input_data_ready : std_logic := '0';
    signal asi_input_data_sop : std_logic := '0';
    signal asi_input_data_eop : std_logic := '0';
    signal aso_output_data_data : std_logic_vector (7 downto 0) := (others => '0');
    signal aso_output_data_endofpacket : std_logic := '0';
    signal aso_output_data_startofpacket : std_logic := '0';
    signal aso_output_data_valid : std_logic := '0';
    signal aso_output_data_ready : std_logic := '0';
    signal aso_output_data_data_err : std_logic := '1';
    signal aso_output_data_last_err : std_logic := '1';
    signal params_address : std_logic_vector(3 downto 0)  := (others => '0');
    signal params_read : std_logic := '0';
    signal params_write : std_logic := '0';
    signal params_readdata : std_logic_vector (7 downto 0) := (others => '0');
    signal params_writedata : std_logic_vector (7 downto 0) := x"10";
    signal params_waitrequest : std_logic := '0';

    constant C_TCLK : time := 20 ns;
    signal reset_source : std_logic := '1';

    constant sx : real := 4.0;
    constant sy : real := 4.0;
    constant x_inc : real := 1.0/sx;
    constant y_inc : real := 1.0/sy;

    constant C_WIDTH  : natural := 20;
    constant C_HEIGHT : natural := 20;

    constant C_SX_FIXED     : std_logic_vector(C_MM_DATA_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(integer( floor(sx * 2**C_SCALE_FRAC) ), C_MM_DATA_WIDTH));
    constant C_SY_FIXED     : std_logic_vector(C_MM_DATA_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(integer( floor(sy * 2**C_SCALE_FRAC) ), C_MM_DATA_WIDTH));
    constant C_X_INC_FIXED  : std_logic_vector(2*C_MM_DATA_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(integer( floor(x_inc * 2**C_NFRAC) ), 2*C_MM_DATA_WIDTH));
    constant C_Y_INC_FIXED  : std_logic_vector(2*C_MM_DATA_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(integer( floor(y_inc * 2**C_NFRAC) ), 2*C_MM_DATA_WIDTH));

    constant C_WIDTH_FIXED : std_logic_vector(2*C_MM_DATA_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(C_WIDTH, 2*C_MM_DATA_WIDTH));
    constant C_HEIGHT_FIXED : std_logic_vector(2*C_MM_DATA_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(C_HEIGHT, 2*C_MM_DATA_WIDTH));

    signal avmm_addr_wr : integer range 0 to 2**C_MM_ADDR_WIDTH-1;
begin
    DUT_i0: entity work.acc_bilinear_scaling
        port map (
            clk => clk,
            reset => reset,
            asi_input_data_data => asi_input_data_data,
            asi_input_data_valid => asi_input_data_valid,
            asi_input_data_ready => asi_input_data_ready,
            asi_input_data_sop => asi_input_data_sop,
            asi_input_data_eop => asi_input_data_eop,
            aso_output_data_data => aso_output_data_data,
            aso_output_data_endofpacket => aso_output_data_endofpacket,
            aso_output_data_startofpacket => aso_output_data_startofpacket,
            aso_output_data_valid => aso_output_data_valid,
            aso_output_data_ready => aso_output_data_ready,
            params_address => params_address,
            params_read => params_read,
            params_write => params_write,
            params_readdata => params_readdata,
            params_writedata => params_writedata,
            params_waitrequest => params_waitrequest
        );

    AVS_SOURCE_i0 : entity work.avs_source
        generic map (
            G_PACKET_SIZE       => C_WIDTH,
            G_VALID_PROB        => 0.5,
            G_FILE_TEST_VECTORS => "input.txt",
            G_DATA_FORMAT       => "bin"
        )
        port map(
            clk => clk,
            reset => reset_source,
            data => asi_input_data_data,
            valid => asi_input_data_valid,
            ready => asi_input_data_ready,
            last => asi_input_data_eop
        );

    AVS_SINK_i0 : entity work.avs_sink
        generic map (
            G_PACKET_SIZE       => C_WIDTH * to_integer(unsigned(C_SX_FIXED)) / 2**C_SCALE_FRAC,
            G_READY_PROB        => 0.5,
            G_FILE_OUTPUT       => "output.txt",
            G_FILE_OUTPUT_REF   => "output_ref.txt",
            G_DATA_FORMAT       => "bin"
        )
        port map(
            clk => clk,
            reset => reset,
            data => aso_output_data_data,
            ready => aso_output_data_ready,
            valid => aso_output_data_valid,
            last => aso_output_data_endofpacket,
            error_in_data => aso_output_data_data_err,
            error_in_last => aso_output_data_last_err
        );

    clk <= not clk after C_TCLK/2;
    reset <= '0' after C_TCLK;

    params_address <= std_logic_vector(to_unsigned(avmm_addr_wr, C_MM_ADDR_WIDTH));

    process is
    begin
        wait until reset='0';
        wait until rising_edge(clk);

        avmm_addr_wr <= C_WIDTH_ADDR;
        params_writedata <= C_WIDTH_FIXED(C_MM_DATA_WIDTH-1 downto 0);
        params_write <= '1';
        wait for C_TCLK;
        avmm_addr_wr <= C_WIDTH_ADDR+1;
        params_writedata <= C_WIDTH_FIXED(2*C_MM_DATA_WIDTH-1 downto C_MM_DATA_WIDTH);
        params_write <= '1';
        wait for C_TCLK;

        avmm_addr_wr <= C_HEIGHT_ADDR;
        params_writedata <= C_HEIGHT_FIXED(C_MM_DATA_WIDTH-1 downto 0);
        params_write <= '1';
        wait for C_TCLK;
        avmm_addr_wr <= C_HEIGHT_ADDR+1;
        params_writedata <= C_HEIGHT_FIXED(2*C_MM_DATA_WIDTH-1 downto C_MM_DATA_WIDTH);
        params_write <= '1';
        wait for C_TCLK;

        avmm_addr_wr <= C_SX_ADDR;
        params_writedata <= C_SX_FIXED;
        params_write <= '1';
        wait for C_TCLK;

        avmm_addr_wr <= C_SY_ADDR;
        params_writedata <= C_SY_FIXED;
        params_write <= '1';
        wait for C_TCLK;

        avmm_addr_wr <= C_X_INC_ADDR;
        params_writedata <= C_X_INC_FIXED(C_MM_DATA_WIDTH-1 downto 0);
        params_write <= '1';
        wait for C_TCLK;
        avmm_addr_wr <= C_X_INC_ADDR+1;
        params_writedata <= C_X_INC_FIXED(2*C_MM_DATA_WIDTH-1 downto C_MM_DATA_WIDTH);
        params_write <= '1';
        wait for C_TCLK;

        avmm_addr_wr <= C_Y_INC_ADDR;
        params_writedata <= C_Y_INC_FIXED(C_MM_DATA_WIDTH-1 downto 0);
        params_write <= '1';
        wait for C_TCLK;
        avmm_addr_wr <= C_Y_INC_ADDR+1;
        params_writedata <= C_Y_INC_FIXED(2*C_MM_DATA_WIDTH-1 downto C_MM_DATA_WIDTH);
        params_write <= '1';
        wait for C_TCLK;

        params_write <= '0';
        reset_source <= '0';

        wait for 120 ms;
        avmm_addr_wr <= C_CTL_ADDR;
        params_writedata <= (C_CTL_RESET => '1', others => '0');
        params_write <= '1';
        wait for C_TCLK;
        params_write <= '0';

        wait;
    end process;

end architecture Test;
