#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "altera_avalon_sgdma_descriptor.h"
#include "altera_avalon_sgdma.h"
#include "altera_avalon_sgdma_regs.h"
#include "io.h"
#include "system.h"

#include "bilinear_scaling_hw.h"
#include "software_model/bilinear_scaling.h"
#include "software_model/utils.h"

alt_sgdma_descriptor* descriptor_alloc(uint16_t number_of_buffers, void** allocated_memory) {
    alt_sgdma_descriptor* result;
    void* temp_ptr;

    /* Allocate memory for number_of_buffers + 1 descriptors. Last descriptors is the null descriptor. */
    temp_ptr = malloc((number_of_buffers + 2)*ALTERA_AVALON_SGDMA_DESCRIPTOR_SIZE);
    assert(temp_ptr != NULL);

    /* Save a pointer to the allocated memory. */
    *allocated_memory = temp_ptr;

    /* Slide the pointer for proper alignment. */
    while((((uint32_t)temp_ptr) % ALTERA_AVALON_SGDMA_DESCRIPTOR_SIZE) != 0) {
        temp_ptr++;
    }

    result = (alt_sgdma_descriptor*) temp_ptr;

    /* Clear out the owned by hardware bit.*/
    result[number_of_buffers].control = 0x00;

    return result;
}


void create_transmit_descriptors(alt_sgdma_descriptor* descriptors, image_t image) {
    for(uint32_t i=0; i<image.height; i++) {
        alt_avalon_sgdma_construct_mem_to_stream_desc(
            &descriptors[i],            /* Current descriptor pointer. */
            &descriptors[i+1],          /* Next descriptor pointer. */
            (uint32_t*)image.data[i],   /* Read buffer location. */
            (uint16_t)image.width,      /* Length of the buffer. */
            0,                          /* Reads are not from a fixed location. */
            0,                          /* Start-of-packet disabled. */
            1,                          /* End-of-packet enabled. */
            0                           /* One channel only. */
        );
    }
}


void create_receive_descriptors(alt_sgdma_descriptor* descriptors, image_t image) {
    for(uint32_t i=0; i<image.height; i++) {
        alt_avalon_sgdma_construct_stream_to_mem_desc(
            &descriptors[i],                            /* Current descriptor pointer. */
            &descriptors[i+1],                          /* Next descriptor pointer. */
            (uint32_t*)image.data[i],                   /* Write buffer location. */
            (uint16_t)image.width*sizeof(**image.data), /* Length of the buffer. */
            0
        );
    }
}


image_t bilinear_scaling_hw(
            image_t input,
            float sx_float,
            float sy_float,
            alt_sgdma_dev* sgdma_in,
            alt_sgdma_dev* sgdma_out,
            volatile uint16_t* tx_done,
            volatile uint16_t* rx_done) {

    /* Conversion to fixed point of the scaling factors. */
    uint8_t sx = to_fixed_point(sx_float, BILINEAR_SCALING_SF_NINT, BILINEAR_SCALING_SF_NFRAC);
    uint8_t sy = to_fixed_point(sy_float, BILINEAR_SCALING_SF_NINT, BILINEAR_SCALING_SF_NFRAC);

    /* Corresponding float values of the scaling factors in fixed point. */
    float sx_fx = from_fixed_point(sx, BILINEAR_SCALING_SF_NFRAC);
    float sy_fx = from_fixed_point(sy, BILINEAR_SCALING_SF_NFRAC);

    /* Allocate output image memory. */
    image_t output = image_alloc(input.height*sy_fx, input.width*sx_fx);

    /* Input image coordinates increment. */
    /* Fixed point representation (BILINEAR_SCALING_NINT, BILINEAR_SCALING_NFRAC) */
    uint16_t increment_x = to_fixed_point(1/sx_fx, BILINEAR_SCALING_NINT, BILINEAR_SCALING_NFRAC);
    uint16_t increment_y = to_fixed_point(1/sy_fx, BILINEAR_SCALING_NINT, BILINEAR_SCALING_NFRAC);

    /* Pointers to memory allocated for SGDMA descriptors. */
    void* transmit_alloc;
    void* receive_alloc;

    /* Allocate SGDMA descriptors. */
    alt_sgdma_descriptor* transmit_descriptors = descriptor_alloc(input.height, &transmit_alloc);
    alt_sgdma_descriptor* receive_descriptors = descriptor_alloc(output.height, &receive_alloc);

    /* Create SGDMA descriptors. */
    create_transmit_descriptors(transmit_descriptors, input);
    create_receive_descriptors(receive_descriptors, output);

    transmit_descriptors[input.height].control = 0x00;
    receive_descriptors[output.height].control = 0x00;

    /* Write params to the peripheral. */
    IOWR_16DIRECT(ACC_BILINEAR_SCALING_BASE, ACC_BILINEAR_SCALING_WIDTH_ADDR, input.width);
    IOWR_16DIRECT(ACC_BILINEAR_SCALING_BASE, ACC_BILINEAR_SCALING_HEIGHT_ADDR, input.height);
    IOWR_16DIRECT(ACC_BILINEAR_SCALING_BASE, ACC_BILINEAR_SCALING_SX_INV_ADDR, increment_x);
    IOWR_16DIRECT(ACC_BILINEAR_SCALING_BASE, ACC_BILINEAR_SCALING_SY_INV_ADDR, increment_y);
    IOWR_8DIRECT(ACC_BILINEAR_SCALING_BASE, ACC_BILINEAR_SCALING_SX_ADDR, sx);
    IOWR_8DIRECT(ACC_BILINEAR_SCALING_BASE, ACC_BILINEAR_SCALING_SY_ADDR, sy);

    /* Start SGDMAs. */
    if(alt_avalon_sgdma_do_async_transfer(sgdma_out, &transmit_descriptors[0]) != 0)
    {
        printf("Writing the head of the transmit descriptor list to the DMA failed\n");
    }
    if(alt_avalon_sgdma_do_async_transfer(sgdma_in, &receive_descriptors[0]) != 0)
    {
        printf("Writing the head of the receive descriptor list to the DMA failed\n");
    }

    /* Wait for SGDMA interrupts to fire. */
    while(*tx_done == 0x0000);
    printf("Transmit SGDMA completed.\n");
    while(*rx_done == 0x0000);
    printf("Receive SGDMA completed.\n");

    /* Set done bit to reset system internally. */
    IOWR_8DIRECT(ACC_BILINEAR_SCALING_BASE, ACC_BILINEAR_SCALING_CTL_ADDR, 0x01);

    /* Reset flags. */
    *rx_done = 0x0000;
    *tx_done = 0x0000;

    /* Stop SGDMAs. */
    alt_avalon_sgdma_stop(sgdma_in);
    alt_avalon_sgdma_stop(sgdma_out);

    /* Free memory allocated for descripotrs. */
    free(transmit_alloc);
    free(receive_alloc);

    return output;
}
