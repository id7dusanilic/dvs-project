#ifndef __BILINEAR_SCALING_SW_H__
#define __BILINEAR_SCALING_SW_H__

#include <stdint.h>

#include "utils.h"

/* Scaling factors fixed point configuration */
#define BILINEAR_SCALING_SF_NFRAC (5)
#define BILINEAR_SCALING_SF_NINT (3)

/* Computation fixed point configuration */
#define BILINEAR_SCALING_NFRAC (12)
#define BILINEAR_SCALING_NINT (16-BILINEAR_SCALING_NFRAC)

#define GET_FRAC_UINT32_T(x, nfrac) ((uint32_t)x & (uint32_t)((1 << nfrac) - 1))
#define GET_INT_UINT32_T(x, nfrac) ((uint32_t)x & (UINT32_MAX & ~((uint32_t)((1 << nfrac) - 1)))) >> nfrac

image_t bilinear_scaling_sw(image_t input, float sx, float sy);

#endif
