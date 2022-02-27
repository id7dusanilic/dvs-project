#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "utils.h"

int main(int argc, char** argv) {
    uint32_t width, height;

    if(argc <3) {
        printf("Input and output filenames not specified! Aborting...\n");
        exit(1);
    }

    char* input_filename = argv[1];
    char* output_filename = argv[2];

    uint8_t** image_in = bin2image(input_filename, &height, &width);

    invert_image(image_in, height, width);

    save_to_pgm(output_filename, image_in, width, height);

    matrix_free(image_in, height);

    return 0;
}
