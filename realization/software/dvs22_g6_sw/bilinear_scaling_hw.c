#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "altera_avalon_sgdma_descriptor.h"
#include "altera_avalon_sgdma.h"
#include "altera_avalon_sgdma_regs.h"
#include "io.h"

#include "software_model/utils.h"

alt_sgdma_descriptor* descriptor_alloc(uint16_t number_of_buffers, void** allocated_memory) {
    alt_sgdma_descriptor* result;
    void* temp_ptr;

    /* Allocate memory for number_of_buffers + 1 descriptors. Last descriptors is the null descriptor. */
    temp_ptr = malloc((number_of_buffers + 2)*ALTERA_AVALON_SGDMA_DESCRIPTOR_SIZE);
    assert(temp_ptr != NULL);

    /* Save a pointer to the allocated memory. */
    *allocated_memory = temp_ptr;

    /* Slide the pointer for proper allignment. */
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
            0,                          /* End-of-packet disabled. */
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
            float sx,
            float sy,
            alt_sgdma_dev* sgdma_in,
            alt_sgdma_dev* sgdma_out,
            uint16_t* tx_done,
            uint16_t* rx_done) {

    void* transmit_alloc;
    void* receive_alloc;

    /* Allocate output image memory. */
    image_t output = image_alloc((uint32_t) (input.height * sy), (uint32_t) (input.width * sx));

    /* Allocate SGDMA descriptors. */
    alt_sgdma_descriptor* transmit_descriptors = descriptor_alloc(input.height, &transmit_alloc);
    alt_sgdma_descriptor* receive_descriptors = descriptor_alloc(output.height, &receive_alloc);

    /* Create SGDMA descriptors. */
    create_transmit_descriptors(transmit_descriptors, input);
    create_receive_descriptors(receive_descriptors, output);

    /* Write params to the peripheral. */
    /* TODO */
    /* IOWR_16DIRECT(ACC_BILINEAR_FUNCTION_BASE, PARAM_ADDRESS, PARAM); */

    /* Start SGDMAs. */
    if(alt_avalon_sgdma_do_async_transfer(sgdma_in, &transmit_descriptors[0]) != 0)
    {
        printf("Writing the head of the transmit descriptor list to the DMA failed\n");
    }
    if(alt_avalon_sgdma_do_async_transfer(sgdma_out, &receive_descriptors[0]) != 0)
    {
        printf("Writing the head of the receive descriptor list to the DMA failed\n");
    }

    /* Wait for SGDMA interrupts to fire. */
    while(*tx_done == 0x0000);
    printf("Transmit SGDMA completed.\n");
    while(*rx_done == 0x0000);
    printf("Receive SGDMA completed.\n");

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
