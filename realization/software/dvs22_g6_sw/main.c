#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#ifndef SOFTWARE_MODEL_ONLY
#include "altera_avalon_performance_counter.h"
#include "altera_avalon_sgdma_descriptor.h"
#include "altera_avalon_sgdma.h"
#include "altera_avalon_sgdma_regs.h"
#include "system.h"

#include "bilinear_scaling_hw.h"
#endif
#include "software_model/bilinear_scaling.h"
#include "software_model/utils.h"

#ifndef SOFTWARE_MODEL_ONLY
#define PATH_PREPEND_LEN    (10)    /* Length of ALTERA_HOSTFS_NAME"/". */
#define RESULT_HW_NAME      "result_hw"
#else
#define PATH_PREPEND_LEN    (0)
#endif
#define RESULT_SW_NAME      "result_sw"
#define MAX_STRLEN          (255)   /* Maximum string length, used for static memory allocation. */
#define SAME_AS_BEFORE      '@'     /* Character used to signal that the same image is being used from previous input. */
#define SAVE_FORMAT_BIN     'b'     /* Character indicating output image save format is bin */
#define SAVE_FORMAT_PGM     'p'     /* Character indicating output image save format is pgm */

void get_input(
        char* input_filename,
        char* save_format,
        unsigned* ul_x,
        unsigned* ul_y,
        unsigned* dr_x,
        unsigned* dr_y,
        float* sx,
        float* sy);

#ifndef SOFTWARE_MODEL_ONLY
void transmit_callback_function(void* context) {
    uint16_t* tx_done = (uint16_t*) context;
    *tx_done = 0x0001;
}

void receive_callback_function(void* context) {
    uint16_t* rx_done = (uint16_t*) context;
    *rx_done = 0x0001;
}
#endif

int main() {

#ifndef SOFTWARE_MODEL_ONLY
    volatile uint16_t tx_done = 0x0000;
    volatile uint16_t rx_done = 0x0000;
#endif

#ifndef SOFTWARE_MODEL_ONLY
    /* Filename holders, prepended with hostfs name so that relative paths can be used. */
    char input_filename[MAX_STRLEN] = ALTERA_HOSTFS_NAME"/";
    char output_filename[MAX_STRLEN] = ALTERA_HOSTFS_NAME"/";
#else
    /* Filename holders. */
    char input_filename[MAX_STRLEN];
    char output_filename[MAX_STRLEN];
#endif

    /* Output file format. */
    char save_format;

    /* Endpoint coordinates for the input segment. */
    unsigned ul_x, ul_y, dr_x, dr_y;

    /* Scaling coefficients. */
    float sx, sy;

    /* Number of jobs done. */
    unsigned num = 0;

    image_t image_in;

#ifndef SOFTWARE_MODEL_ONLY
    /* SGDMA device instances */
    alt_sgdma_dev* sgdma_in = alt_avalon_sgdma_open(SGDMA_IN_NAME);
    alt_sgdma_dev* sgdma_out = alt_avalon_sgdma_open(SGDMA_OUT_NAME);

    /* Registering sgdma_out transmit callback function. */
    alt_avalon_sgdma_register_callback(
        sgdma_out,
        &transmit_callback_function,
        (ALTERA_AVALON_SGDMA_CONTROL_IE_GLOBAL_MSK |
         ALTERA_AVALON_SGDMA_CONTROL_IE_CHAIN_COMPLETED_MSK |
         ALTERA_AVALON_SGDMA_CONTROL_PARK_MSK),
        (void*)&tx_done);

    /* Registering sgdma_in receive callback function. */
    alt_avalon_sgdma_register_callback(
        sgdma_in,
        &receive_callback_function,
        (ALTERA_AVALON_SGDMA_CONTROL_IE_GLOBAL_MSK |
         ALTERA_AVALON_SGDMA_CONTROL_IE_CHAIN_COMPLETED_MSK |
         ALTERA_AVALON_SGDMA_CONTROL_PARK_MSK),
        (void*)&rx_done);
#endif

    /* Endless loop processing */
    for (;;) {

        /* Populate required fields from stdin. */
        get_input(
            input_filename,
            &save_format,
            &ul_x,
            &ul_y,
            &dr_x,
            &dr_y,
            &sx,
            &sy);

        /* If the input filename is SAME_AS_BEFORE don't load the image again. */
        if ((input_filename[PATH_PREPEND_LEN] != SAME_AS_BEFORE) || (num == 0)) {
            if (!image_in.data) image_free(image_in);
            printf("Loading image %s...\n", input_filename);
            image_in = bin2image(input_filename);
            printf("Image %s loaded.\n", input_filename);
        }

        /* Segment dimensions. */
        unsigned seg_width = dr_x - ul_x + 1;
        unsigned seg_height = dr_y - ul_y + 1;

        /* Extract segment from the input image. */
        image_t input_segment = extract_segment(image_in, ul_x, ul_y, seg_height, seg_width);
        printf("Extracted segment.\n");

#ifndef SOFTWARE_MODEL_ONLY
        /* Reset the performance counter unit. */
        PERF_RESET(PERFORMANCE_COUNTER_BASE);
        PERF_START_MEASURING(PERFORMANCE_COUNTER_BASE);
#endif

#ifndef SOFTWARE_MODEL_ONLY
        /* Software processing. */
        PERF_BEGIN(PERFORMANCE_COUNTER_BASE, 1);
#endif
        image_t output_image_sw = bilinear_scaling_sw(input_segment, sx, sy);
#ifndef SOFTWARE_MODEL_ONLY
        PERF_END(PERFORMANCE_COUNTER_BASE, 1);
#endif
        printf("Image scaled (software).\n\n");

#ifndef SOFTWARE_MODEL_ONLY
        /* Hardware processing. */
        PERF_BEGIN(PERFORMANCE_COUNTER_BASE, 2);
        image_t output_image_hw = bilinear_scaling_hw(input_segment, sx, sy, sgdma_in, sgdma_out, &tx_done, &rx_done);
        PERF_END(PERFORMANCE_COUNTER_BASE, 2);
        printf("Image scaled (hardware).\n\n");
#endif

        if (save_format == SAVE_FORMAT_PGM) {
            /* Save to PGM for easier result display. */
#ifndef SOFTWARE_MODEL_ONLY
            sprintf(output_filename + PATH_PREPEND_LEN, "%s", RESULT_HW_NAME".pgm");
            save_to_pgm(output_filename, output_image_hw);
            printf("\nImage %s saved.\n", output_filename);
#endif
            sprintf(output_filename + PATH_PREPEND_LEN, "%s", RESULT_SW_NAME".pgm");
            save_to_pgm(output_filename, output_image_sw);
            printf("\nImage %s saved.\n", output_filename);
        }
        else if (save_format == SAVE_FORMAT_BIN) {
#ifndef SOFTWARE_MODEL_ONLY
            sprintf(output_filename + PATH_PREPEND_LEN, "%s", RESULT_HW_NAME".bin");
            save_to_bin(output_filename, output_image_hw);
            printf("\nImage %s saved.\n", output_filename);
#endif
            sprintf(output_filename + PATH_PREPEND_LEN, "%s", RESULT_SW_NAME".bin");
            save_to_bin(output_filename, output_image_sw);
            printf("\nImage %s saved.\n", output_filename);
        }

#ifndef SOFTWARE_MODEL_ONLY
        /* Print performance comparison results. */
        perf_print_formatted_report(
                (void *)PERFORMANCE_COUNTER_BASE,
                alt_get_cpu_freq(),
                2,
                "Software",
                "Hardware");
#endif

        /* Update number of jobs done */
        num++;

        /* Deallocate used memory */
        image_free(output_image_sw);
#ifndef SOFTWARE_MODEL_ONLY
        image_free(output_image_hw);
#endif
        free(input_segment.data);     /* Input segment is a shallow copy. */
    }

    printf("Exiting.\n");
    return 0;
}


void get_input(
        char* input_filename,
        char* save_format,
        unsigned* ul_x,
        unsigned* ul_y,
        unsigned* dr_x,
        unsigned* dr_y,
        float* sx,
        float* sy) {

    printf("Enter input filename: ");
    scanf("%s", input_filename + PATH_PREPEND_LEN);
    printf("\nEnter output image format: ");
    scanf(" %c", save_format);
    printf("\nEnter endpoint coordinates: ");
    scanf("%u %u %u %u", ul_x, ul_y, dr_x, dr_y);
    assert((*dr_x > *ul_x) && (*dr_y > *ul_y));
    printf("\nEnter scaling factors: ");
    scanf("%f %f", sx, sy);
    assert((*sx > 0) && (*sy > 0));
}
