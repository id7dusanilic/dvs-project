#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "software_model/utils.h"
#include "system.h"
#include "altera_avalon_performance_counter.h"


#define MAX_STRLEN (256)
#define ALTERA_HOSTFS_NAME_LEN (10)
#define SAME_AS_BEFORE '@'

int main() {
    char input_filename[MAX_STRLEN] = ALTERA_HOSTFS_NAME"/";
    char output_filename[MAX_STRLEN] = ALTERA_HOSTFS_NAME"/";

    unsigned ul_x = 0;
    unsigned ul_y = 0;
    unsigned dr_x = 100;
    unsigned dr_y = 90;

    unsigned out_width;
    unsigned out_height;

    float sx = 0.25;
    float sy = 0.25;

    image_t image_in;

    for (;;) {
        printf("Enter input filename: ");
        scanf("%s", input_filename + ALTERA_HOSTFS_NAME_LEN);
        if (input_filename[ALTERA_HOSTFS_NAME_LEN] != SAME_AS_BEFORE) {
            if (!image_in.data) image_free(image_in);
            image_in = bin2image(input_filename);
            printf("Image %s loaded.\n", input_filename);
        }
        printf("\nEnter output filename: ");
        scanf("%s", output_filename + ALTERA_HOSTFS_NAME_LEN);
        printf("\nEnter endpoint coordinates: ");
        scanf("%u %u %u %u", &ul_x, &ul_y, &dr_x, &dr_y);
        printf("\nEnter scaling factors: ");
        scanf("%f %f", &sx, &sy);

        seg_width = dr_x - ul_x + 1;
        seg_height = dr_y - ul_y + 1;

        image_t input_image = extract_segment(image_in, ul_x, ul_y, seg_height, seg_width);
        printf("Extracted segment.\n");

        PERF_RESET(PERFORMANCE_COUNTER_BASE);
        PERF_START_MEASURING(PERFORMANCE_COUNTER_BASE);

        PERF_BEGIN(PERFORMANCE_COUNTER_BASE, 1);
        image_t output_image = bilinear_scaling_sw(input_image, sx, sy);
        PERF_END(PERFORMANCE_COUNTER_BASE, 1);
        printf("Image scaled.\n\n");

        save_to_pgm(output_filename, output_image);
        printf("\nImage saved.\n");

        perf_print_formatted_report(
                (void *)PERFORMANCE_COUNTER_BASE,
                alt_get_cpu_freq(),
                1,
                "processing_sw");

        image_free(output_image);
        free(input_image.data);
    }

    printf("Exiting.\n");
    return 0;
}
