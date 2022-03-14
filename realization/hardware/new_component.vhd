-- new_component.vhd

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

entity new_component is
	port (
		scaling_coeffs_address        : in  std_logic                    := '0';             -- scaling_coeffs.address
		scaling_coeffs_read           : in  std_logic                    := '0';             --               .read
		scaling_coeffs_write          : in  std_logic                    := '0';             --               .write
		scaling_coeffs_readdata       : out std_logic_vector(7 downto 0);                    --               .readdata
		scaling_coeffs_writedata      : in  std_logic_vector(7 downto 0) := (others => '0'); --               .writedata
		scaling_coeffs_waitrequest    : out std_logic;                                       --               .waitrequest
		clk                           : in  std_logic                    := '0';             --            clk.clk
		reset                         : in  std_logic                    := '0';             --          reset.reset
		asi_input_data_data           : in  std_logic_vector(7 downto 0) := (others => '0'); --     image_data.data
		asi_input_data_valid          : in  std_logic                    := '0';             --               .valid
		asi_input_data_ready          : out std_logic;                                       --               .ready
		asi_input_data_sop            : in  std_logic                    := '0';             --               .startofpacket
		asi_input_data_eop            : in  std_logic                    := '0';             --               .endofpacket
		aso_output_data_data          : out std_logic_vector(7 downto 0);                    --    output_data.data
		aso_output_data_endofpacket   : out std_logic;                                       --               .endofpacket
		aso_output_data_startofpacket : out std_logic;                                       --               .startofpacket
		aso_output_data_valid         : out std_logic;                                       --               .valid
		aso_output_data_ready         : in  std_logic                    := '0'              --               .ready
	);
end entity new_component;

architecture rtl of new_component is
begin

	-- TODO: Auto-generated HDL template

	scaling_coeffs_readdata <= "00000000";

	scaling_coeffs_waitrequest <= '0';

	asi_input_data_ready <= '0';

	aso_output_data_valid <= '0';

	aso_output_data_data <= "00000000";

	aso_output_data_startofpacket <= '0';

	aso_output_data_endofpacket <= '0';

end architecture rtl; -- of new_component
