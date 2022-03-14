-- acc_bilinear_scaling.vhd

-- This file was auto-generated as a prototype implementation of a module
-- created in component editor.  It ties off all outputs to ground and
-- ignores all inputs.  It needs to be edited to make it do something
-- useful.
-- 
-- This file will not be automatically regenerated.  You should check it in
-- to your version control system if you want to keep it.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity acc_bilinear_scaling is
	port (
		clk                           : in  std_logic                     := '0';             --            clk.clk
		reset                         : in  std_logic                     := '0';             --          reset.reset
		asi_input_data_data           : in  std_logic_vector(7 downto 0)  := (others => '0'); --     input_data.data
		asi_input_data_valid          : in  std_logic                     := '0';             --               .valid
		asi_input_data_ready          : out std_logic;                                        --               .ready
		asi_input_data_sop            : in  std_logic                     := '0';             --               .startofpacket
		asi_input_data_eop            : in  std_logic                     := '0';             --               .endofpacket
		aso_output_data_data          : out std_logic_vector(7 downto 0);                     --    output_data.data
		aso_output_data_endofpacket   : out std_logic;                                        --               .endofpacket
		aso_output_data_startofpacket : out std_logic;                                        --               .startofpacket
		aso_output_data_valid         : out std_logic;                                        --               .valid
		aso_output_data_ready         : in  std_logic                     := '0';             --               .ready
		params_address                : in  std_logic_vector(2 downto 0)  := (others => '0'); -- scaling_coeffs.address
		params_read                   : in  std_logic                     := '0';             --               .read
		params_write                  : in  std_logic                     := '0';             --               .write
		params_readdata               : out std_logic_vector(15 downto 0);                    --               .readdata
		params_writedata              : in  std_logic_vector(15 downto 0) := (others => '0'); --               .writedata
		params_waitrequest            : out std_logic                                         --               .waitrequest
	);
end entity acc_bilinear_scaling;

architecture rtl of acc_bilinear_scaling is

	-- TODO: Auto-generated HDL template



	asi_input_data_ready <= '0';

	aso_output_data_valid <= '0';

	aso_output_data_data <= "00000000";

	aso_output_data_startofpacket <= '0';

	aso_output_data_endofpacket <= '0';

	params_readdata <= "0000000000000000";

	params_waitrequest <= '0';

end architecture rtl; -- of acc_bilinear_scaling
