#include <stdint.h>

#define DIM_BYTE_COUNT (4)

typedef struct {
    uint8_t** data;
    uint32_t height;
    uint32_t width;
} image_t;

void save_to_pgm(const char* filename, image_t image);

uint8_t** matrix_alloc(uint32_t height, uint32_t width);
void matrix_free(uint8_t** matrix, uint32_t height);

image_t image_alloc(uint32_t height, uint32_t width);
void image_free(image_t image);

image_t bin2image(const char* filename);

void invert_image(image_t image);
