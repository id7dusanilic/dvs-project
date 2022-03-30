#ifndef __BILINEAR_SCALING_HW_H__
#define __BILINEAR_SCALING_HW_H__

#include <stdint.h>

#include "software_model/utils.h"

#define ACC_BILINEAR_SCALING_SX_ADDR        (0x0)
#define ACC_BILINEAR_SCALING_SY_ADDR        (0x1)
#define ACC_BILINEAR_SCALING_SX_INV_ADDR    (0x2)
#define ACC_BILINEAR_SCALING_SY_INV_ADDR    (0x4)
#define ACC_BILINEAR_SCALING_WIDTH_ADDR     (0x6)
#define ACC_BILINEAR_SCALING_HEIGHT_ADDR    (0x8)
#define ACC_BILINEAR_SCALING_CTL_ADDR       (0xa)

image_t bilinear_scaling_hw(
        image_t input,
        float sx_float,
        float sy_float,
        alt_sgdma_dev* sgdma_in,
        alt_sgdma_dev* sgdma_out,
        volatile uint16_t* tx_done,
        volatile uint16_t* rx_done);

#endif
