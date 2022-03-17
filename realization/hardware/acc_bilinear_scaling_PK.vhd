library IEEE;
use IEEE.std_logic_1164.all;

package acc_bilinear_scaling_PK is
    constant C_SCALE_INT        : natural := 3;
    constant C_SCALE_FRAC       : natural := 5;
    constant C_SCALE_WIDTH      : natural := C_SCALE_INT + C_SCALE_FRAC;

    constant C_SCALE_INV_INT    : natural := 4;
    constant C_SCALE_INV_FRAC   : natural := 12;
    constant C_SCALE_INV_WIDTH  : natural := C_SCALE_INV_INT + C_SCALE_INV_FRAC;

    constant C_DIM_WIDTH        : natural := 16;

    constant C_ADDR_WIDTH       : natural := 5;
    constant C_DATA_WIDTH       : natural := 8;
    constant C_RAM_DEPTH        : natural := 2**C_ADDR_WIDTH;

    constant C_MM_ADDR_WIDTH    : natural := 3;

    constant C_SX_ADDR          : std_logic_vector(C_MM_ADDR_WIDTH-1 downto 0) := "000";
    constant C_SY_ADDR          : std_logic_vector(C_MM_ADDR_WIDTH-1 downto 0) := "001";
    constant C_SX_INV_ADDR      : std_logic_vector(C_MM_ADDR_WIDTH-1 downto 0) := "010";
    constant C_SY_INV_ADDR      : std_logic_vector(C_MM_ADDR_WIDTH-1 downto 0) := "011";
    constant C_WIDTH_ADDR       : std_logic_vector(C_MM_ADDR_WIDTH-1 downto 0) := "100";
    constant C_HEIGHT_ADDR      : std_logic_vector(C_MM_ADDR_WIDTH-1 downto 0) := "101";
end acc_bilinear_scaling_PK;
