package acc_bilinear_scaling_PK is
    constant C_SCALE_INT        : natural := 3;
    constant C_SCALE_FRAC       : natural := 5;
    constant C_SCALE_WIDTH      : natural := C_SCALE_INT + C_SCALE_FRAC;

    constant C_SCALE_INV_INT    : natural := 4;
    constant C_SCALE_INV_FRAC   : natural := 12;
    constant C_SCALE_INV_WIDTH  : natural := C_SCALE_INT + C_SCALE_FRAC;

    constant C_DIM_WIDTH        : natural := 16;

    constant C_ADDR_WIDTH       : natural := 5;
    constant C_DATA_WIDTH       : natural := 8;
    constant C_RAM_DEPTH        : natural := 2**C_ADDR_WIDTH;
end acc_bilinear_scaling_PK;
