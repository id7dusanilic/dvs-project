#include <stdint.h>

#include "bilinear_scaling.h"
#include "utils.h"

/* Value 0x01 in fixed point representation with BILINEAR_SCALING_NFRAC fractional bits. */
#define ONE_NFRAC (0x01 << BILINEAR_SCALING_NFRAC)


image_t bilinear_scaling_sw(image_t input, float sx_float, float sy_float) {

    /* Conversion to fixed point of the scaling factors. */
    uint8_t sx = to_fixed_point(sx_float, BILINEAR_SCALING_SF_NINT, BILINEAR_SCALING_SF_NFRAC);
    uint8_t sy = to_fixed_point(sy_float, BILINEAR_SCALING_SF_NINT, BILINEAR_SCALING_SF_NFRAC);

    /* Corresponding float values of the scaling factors in fixed point. */
    float sx_fx = from_fixed_point(sx, BILINEAR_SCALING_SF_NFRAC);
    float sy_fx = from_fixed_point(sy, BILINEAR_SCALING_SF_NFRAC);

    /* Allocate output image memory. */
    image_t output = image_alloc(input.height*sy_fx, input.width*sx_fx);

    /* Input image coordinates. */
    /* Fixed point representation (BILINEAR_SCALING_NINT, BILINEAR_SCALING_NFRAC) */
    uint32_t x = 0;
    uint32_t y = 0;

    /* Input image coordinates increment. */
    /* Fixed point representation (BILINEAR_SCALING_NINT, BILINEAR_SCALING_NFRAC) */
    uint16_t increment_x = to_fixed_point(1/sx_float, BILINEAR_SCALING_NINT, BILINEAR_SCALING_NFRAC);
    uint16_t increment_y = to_fixed_point(1/sy_float, BILINEAR_SCALING_NINT, BILINEAR_SCALING_NFRAC);

    /* Fixed point representation (BILINEAR_SCALING_NINT, BILINEAR_SCALING_NFRAC) */
    uint32_t alpha_x, alpha_y;
    /* Fixed point representation (32, 0) */
    uint32_t floor_x, floor_y;
    /* Fixed point representation (32, 0) */
    uint32_t floor_x1, floor_y1;

    /* Fixed point representation (BILINEAR_SCALING_NINT, BILINEAR_SCALING_NFRAC) */
    uint32_t subp_topleft, subp_botleft;
    uint32_t subp_topright, subp_botright;

    /* Fixed point representation (BILINEAR_SCALING_NINT, BILINEAR_SCALING_NFRAC) */
    uint32_t subp_top, subp_bot;

    for(int v=0; v<output.height; v++) {
        /* Getting neccesary parameters. */
        alpha_y = GET_FRAC_UINT32_T(y, BILINEAR_SCALING_NFRAC);
        floor_y = GET_INT_UINT32_T(y, BILINEAR_SCALING_NFRAC);
        /* Saturating if at the last row. */
        floor_y1 = (floor_y >= input.height-1) ? floor_y : floor_y+1;

        x = 0;
        for(int u=0; u<output.width; u++) {
            /* Getting neccesary parameters. */
            alpha_x = GET_FRAC_UINT32_T(x, BILINEAR_SCALING_NFRAC);
            floor_x = GET_INT_UINT32_T(x, BILINEAR_SCALING_NFRAC);
            /* Saturating if at the end of the row. */
            floor_x1 = (floor_x >= input.width-1) ? floor_x : floor_x+1;

            subp_topleft = (ONE_NFRAC - alpha_x)*input.data[floor_y][floor_x];
            subp_botleft = (ONE_NFRAC - alpha_x)*input.data[floor_y1][floor_x];
            subp_topright = alpha_x*input.data[floor_y][floor_x1];
            subp_botright = alpha_x*input.data[floor_y1][floor_x1];

            subp_top = (ONE_NFRAC - alpha_y)*((subp_topleft + subp_topright) >> BILINEAR_SCALING_NFRAC);
            subp_bot = alpha_y*((subp_botleft + subp_botright) >> BILINEAR_SCALING_NFRAC);

            /* Addition and removing fractional bits. */
            output.data[v][u] = (subp_top + subp_bot) >> BILINEAR_SCALING_NFRAC;

            x += increment_x;
        }
        y += increment_y;
    }

    return output;
}
