#include <stdint.h>

#define DIM_BYTE_COUNT (4)

typedef struct {
    uint8_t** data;
    uint32_t height;
    uint32_t width;
} image_t;


uint8_t** matrix_alloc(uint32_t height, uint32_t width);
void matrix_free(uint8_t** matrix, uint32_t height);

image_t image_alloc(uint32_t height, uint32_t width);
void image_free(image_t image);

image_t extract_segment(image_t image, uint32_t start_x, uint32_t start_y, uint16_t rows, uint16_t cols);

double* get_scaled_coordinates(unsigned c, double sc);

image_t bin2image(const char* filename);
void save_to_pgm(const char* filename, image_t image);
void save_to_bin(const char* filename, image_t image);

image_t invert_image(image_t image);

image_t bilinear_scaling(image_t input, double sx, double sy);
