#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#include "system.h"
#include "altera_avalon_performance_counter.h"

#include "software_model/utils.h"

#define MAX_STRLEN (255)            /* Maximum string length, used for static memory allocation. */
#define ALTERA_HOSTFS_NAME_LEN (10) /* Length of ALTERA_HOSTFS_NAME"/". */
#define SAME_AS_BEFORE '@'          /* Character used to signal that the same image is being used from previous input. */
#define SAVE_2_PGM (1)              /* If this is enabled (!= 0) the image will be saved in pgm instead of bin format. */

void get_input(
        char* input_filename,
        char* output_filename,
        unsigned* ul_x,
        unsigned* ul_y,
        unsigned* dr_x,
        unsigned* dr_y,
        float* sx,
        float* sy);


int main() {

    /* Filename holders, prepended with hostfs name so that relative paths can be used. */
    char input_filename[MAX_STRLEN] = ALTERA_HOSTFS_NAME"/";
    char output_filename[MAX_STRLEN] = ALTERA_HOSTFS_NAME"/";

    /* Endpoint coordinates for the input segment. */
    unsigned ul_x, ul_y, dr_x, dr_y;

    /* Scaling coefficients. */
    float sx, sy;

    /* Number of jobs done. */
    unsigned num = 0;

    image_t image_in;

    /* Endless loop processing */
    for (;;) {

        /* Populate required fields from stdin. */
        get_input(
            input_filename,
            output_filename,
            &ul_x,
            &ul_y,
            &dr_x,
            &dr_y,
            &sx,
            &sy);

        /* If the input filename is SAME_AS_BEFORE don't load the image again. */
        if ((input_filename[ALTERA_HOSTFS_NAME_LEN] != SAME_AS_BEFORE) || (num == 0)) {
            if (!image_in.data) image_free(image_in);
            printf("Loading image %s...\n", input_filename);
            image_in = bin2image(input_filename);
            printf("Image %s loaded.\n", input_filename);
        }

        unsigned seg_width = dr_x - ul_x + 1;
        unsigned seg_height = dr_y - ul_y + 1;
        unsigned out_width = seg_width * sx;
        unsigned out_height = seg_height * sy;

        /* Extract segment from the input image. */
        image_t input_segment = extract_segment(image_in, ul_x, ul_y, seg_height, seg_width);
        printf("Extracted segment.\n");

        /* Reset the performance counter unit. */
        PERF_RESET(PERFORMANCE_COUNTER_BASE);
        PERF_START_MEASURING(PERFORMANCE_COUNTER_BASE);

        /* Software processing. */
        PERF_BEGIN(PERFORMANCE_COUNTER_BASE, 1);
        image_t output_image = bilinear_scaling_sw(input_segment, sx, sy);
        PERF_END(PERFORMANCE_COUNTER_BASE, 1);
        printf("Image scaled.\n\n");


#if SAVE_2_PGM != 0
        /* Save to PGM for easier result display. */
        save_to_pgm(output_filename, output_image);
#else
        save_to_bin(output_filename, output_image);
#endif
        printf("\nImage %s saved.\n", output_filename);


        /* Print performance comparison results. */
        perf_print_formatted_report(
                (void *)PERFORMANCE_COUNTER_BASE,
                alt_get_cpu_freq(),
                1,
                "processing_sw");

        /* Update number of jobs done */
        num++;

        /* Deallocate used memory */
        image_free(output_image);
        free(input_segment.data);     /* Input segment is a shallow copy. */
    }

    printf("Exiting.\n");
    return 0;
}


void get_input(
        char* input_filename,
        char* output_filename,
        unsigned* ul_x,
        unsigned* ul_y,
        unsigned* dr_x,
        unsigned* dr_y,
        float* sx,
        float* sy) {

    printf("Enter input filename: ");
    scanf("%s", input_filename + ALTERA_HOSTFS_NAME_LEN);
    printf("\nEnter output filename: ");
    scanf("%s", output_filename + ALTERA_HOSTFS_NAME_LEN);
    printf("\nEnter endpoint coordinates: ");
    scanf("%u %u %u %u", ul_x, ul_y, dr_x, dr_y);
    assert((dr_x > ul_x) && (dr_y > ul_y));
    printf("\nEnter scaling factors: ");
    scanf("%f %f", sx, sy);
    assert((sx > 0) && (sy > 0));
}
