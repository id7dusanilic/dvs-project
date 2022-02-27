#include <stdint.h>

#define DIM_BYTE_COUNT (4)

void save_to_pgm(const char* filename, uint8_t** image, uint32_t width, uint32_t height);

uint8_t** matrix_alloc(uint32_t height, uint32_t width);

void matrix_free(uint8_t** matrix, uint32_t height);

uint8_t** bin2image(const char* filename, uint32_t* height_ptr, uint32_t* width_ptr);

void invert_image(uint8_t** image, uint32_t height, uint32_t width);
