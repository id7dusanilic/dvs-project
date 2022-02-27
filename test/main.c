#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "utils.h"

int main(int argc, char** argv) {
    if(argc <3) {
        printf("Input and output filenames not specified! Aborting...\n");
        exit(1);
    }

    char* input_filename = argv[1];
    char* output_filename = argv[2];

    double sx, sy;

    sx = 5.0;
    sy = 5.0;

    image_t image_in = bin2image(input_filename);

    uint16_t out_width = 300, out_height = 200;
    uint32_t start_x = 100, start_y = 100;
    image_t input_image = extract_segment(image_in, start_x, start_y, out_height, out_width);

    image_t output_image = bilinear_scaling(input_image, sx, sy);
    save_to_pgm(output_filename, output_image);

    image_free(image_in);
    image_free(output_image);
    free(input_image.data);

    return 0;
}
