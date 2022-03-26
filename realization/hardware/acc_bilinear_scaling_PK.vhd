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

    constant C_ADDR_WIDTH       : natural := 16;
    constant C_DATA_WIDTH       : natural := 8;
    constant C_RAM_DEPTH        : natural := 2**C_ADDR_WIDTH;

    constant C_MM_ADDR_WIDTH    : natural := 4;
    constant C_MM_DATA_WIDTH    : natural := 8;

    constant C_SX_ADDR          : natural := 0;
    constant C_SY_ADDR          : natural := 1;
    constant C_SX_INV_ADDR      : natural := 2;
    constant C_SY_INV_ADDR      : natural := 4;
    constant C_WIDTH_ADDR       : natural := 6;
    constant C_HEIGHT_ADDR      : natural := 8;
    constant C_NFRAC            : natural := 12;
end acc_bilinear_scaling_PK;
