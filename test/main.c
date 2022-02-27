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

    image_t image_in = bin2image(input_filename);

    image_t output_image = invert_image(image_in);

    save_to_pgm(output_filename, output_image);

    image_free(image_in);
    image_free(output_image);

    return 0;
}
