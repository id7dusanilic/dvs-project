#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <assert.h>

#include "utils.h"

void save_to_pgm(const char* filename, image_t image) {
    FILE* file = fopen(filename, "w");
    assert(file != NULL);

    fprintf(file, "P5 %ud %ud %d ", image.width, image.height, 255);
    for(int i=0; i<image.height; i++) {
        fwrite(image.data[i], sizeof(**image.data), image.width, file);
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

image_t bin2image(const char* filename) {
    FILE* file = fopen(filename, "r");
    assert(file != NULL);
    uint32_t width, height;

    fread(&width, DIM_BYTE_COUNT, 1, file);
    fread(&height, DIM_BYTE_COUNT, 1, file);

    image_t image = {
        .data = matrix_alloc(height, width),
        .height = height,
        .width = width
    };

    for(int i=0; i<image.height; i++) {
        fread(image.data[i], sizeof(**image.data), image.width, file);
    }

    fclose(file);

    return image;
}

image_t invert_image(image_t input) {
    image_t output = image_alloc(input.height, input.width);

    for(int i=0; i<output.height; i++) {
        for(int j=0; j<output.width; j++) {
            output.data[i][j] = 255 - input.data[i][j];
        }
    }
    return output;
}

image_t image_alloc(uint32_t height, uint32_t width) {
    image_t image = {
        .data = matrix_alloc(height, width),
        .height = height,
        .width = width
    };

    return image;
}

void image_free(image_t image) {
    matrix_free(image.data, image.height);
}

