#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <assert.h>

#include "utils.h"

void save_to_pgm(const char* filename, uint8_t** image, uint32_t width, uint32_t height) {
    FILE* file = fopen(filename, "w");
    assert(file != NULL);

    fprintf(file, "P5 %ud %ud %d ", width, height, 255);
    for(int i=0; i<height; i++) {
        fwrite(image[i], sizeof(**image), width, file);
    }

    fclose(file);
    return;
}

uint8_t** matrix_alloc(uint32_t height, uint32_t width) {
    uint8_t** matrix = malloc(height * sizeof(*matrix));
    for(int i=0; i<height; i++) {
        matrix[i] = malloc(width * sizeof(**matrix));
    }
    return matrix;
}

void matrix_free(uint8_t** matrix, uint32_t height) {
    for(int i=0; i<height; i++) {
        free(matrix[i]);
    }
    free(matrix);
    return;
}

uint8_t** bin2image(const char* filename, uint32_t* height_ptr, uint32_t* width_ptr) {
    FILE* file = fopen(filename, "r");
    assert(file != NULL);

    fread(width_ptr, DIM_BYTE_COUNT, 1, file);
    fread(height_ptr, DIM_BYTE_COUNT, 1, file);

    uint8_t** image = matrix_alloc(*height_ptr, *width_ptr);

    for(int i=0; i<*height_ptr; i++) {
        fread(image[i], sizeof(**image), *width_ptr, file);
    }

    fclose(file);

    return image;
}

void invert_image(uint8_t** image, uint32_t height, uint32_t width) {
    for(int i=0; i<height; i++) {
        for(int j=0; j<width; j++) {
            image[i][j] = 255 - image[i][j];
        }
    }
    return;
}
