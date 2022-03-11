#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <assert.h>

#include "utils.h"

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

image_t extract_segment(image_t image, uint32_t start_x, uint32_t start_y, uint16_t rows, uint16_t cols) {
    image_t segment = {
        .data = malloc(rows * sizeof(*(segment.data))),
        .height = rows,
        .width = cols
    };

    for(int i=0; i<rows; i++) {
        segment.data[i] = &(image.data[i+start_x][start_y]);
    }
    return segment;
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

void save_to_bin(const char* filename, image_t image) {
    FILE* file = fopen(filename, "w");
    assert(file != NULL);

    fwrite(&image.width, sizeof(uint32_t), 1, file);
    fwrite(&image.height, sizeof(uint32_t), 1, file);
    for(int i=0; i<image.height; i++) {
        fwrite(image.data[i], sizeof(**image.data), image.width, file);
    }

    fclose(file);
    return;
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

float* get_scaled_coordinates(unsigned c, float sc) {
    uint32_t num = c * sc;

    float* res = malloc(sizeof(*res) * num);
    for(int i=0; i<num; i++) {
        res[i] = i / sc;
    }
    return res;
}

uint32_t* get_scaled_coordinates_fixed(unsigned c, float sc, unsigned nint, unsigned nfrac) {
    uint32_t num = c * sc;

    uint32_t* res = malloc(sizeof(*res) * num);
    for(int i=0; i<num; i++) {
        res[i] = to_fixed_point(i / sc, nint, nfrac);
    }
    return res;
}

float from_fixed_point(uint32_t input, unsigned nfrac) {
    return ((float) input) / (1<<nfrac);
}

uint32_t to_fixed_point(float input, unsigned nint, unsigned nfrac) {
    return (uint32_t) (input * (1<<nfrac)) & ((1<<(nint+nfrac)) - 1);
}

image_t bilinear_scaling(image_t input, float sx, float sy) {
    unsigned nfrac = 4, nint = 19;
    image_t output = image_alloc((uint32_t) (input.height * sy), (uint32_t) (input.width * sx));

    uint32_t *x = get_scaled_coordinates_fixed(input.width, sx, nint, nfrac);
    uint32_t *y = get_scaled_coordinates_fixed(input.height, sy, nint, nfrac);

    uint32_t alpha_x, alpha_y;
    uint32_t floor_x, floor_y;
    uint32_t floor_x1, floor_y1;
    uint32_t interp_y0, interp_y1;
    uint64_t wide_output;

    for(int v=0; v<output.height; v++) {
        alpha_y = y[v] & ((1<<nfrac) - 1);
        floor_y = (y[v] - alpha_y) >> nfrac;
        floor_y1 = (floor_y >= input.height-1) ? floor_y : floor_y+1;

        for(int u=0; u<output.width; u++) {
            alpha_x = x[u] & ((1<<nfrac) - 1);
            floor_x = (x[u] - alpha_x) >> nfrac;
            floor_x1 = (floor_x >= input.width-1) ? floor_x : floor_x+1;

            interp_y0 = alpha_x * input.data[floor_y][floor_x1] + ((1<<nfrac)-alpha_x) * input.data[floor_y][floor_x];
            interp_y1 = alpha_x * input.data[floor_y1][floor_x1] + ((1<<nfrac)-alpha_x) * input.data[floor_y1][floor_x];

            wide_output = (alpha_y * interp_y1 + ((1<<nfrac)-alpha_y) * interp_y0);
            output.data[v][u] = wide_output >> (2*nfrac);
        }
    }

    free(x);
    free(y);

    return output;
}
