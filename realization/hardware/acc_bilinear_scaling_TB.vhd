library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

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
    signal aso_output_data_data_err : std_logic := '0';
    signal aso_output_data_last_err : std_logic := '0';
    signal params_address : std_logic_vector(2 downto 0)  := (1 => '1', others => '0');
    signal params_read : std_logic := '0';
    signal params_write : std_logic := '0';
    signal params_readdata : std_logic_vector (15 downto 0) := (others => '0');
    signal params_writedata : std_logic_vector (15 downto 0) := x"0010";
    signal params_waitrequest : std_logic := '0';

    constant C_TCLK : time := 20 ns;

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
            G_PACKET_SIZE       => 8,
            G_VALID_PROB        => 0.5,
            G_FILE_TEST_VECTORS => "input.txt"
        )
        port map(
            clk => clk,
            reset => reset,
            data => asi_input_data_data,
            valid => asi_input_data_valid,
            ready => asi_input_data_ready,
            last => asi_input_data_eop
        );

    clk <= not clk after C_TCLK/2;
    reset <= '0' after C_TCLK;

end architecture Test;
