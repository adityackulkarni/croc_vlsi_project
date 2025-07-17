#ifndef IMAGE_DATA_H
#define IMAGE_DATA_H

#include <stdint.h>

#define IMAGE_WIDTH  8
#define IMAGE_HEIGHT 8

// Example 8x8 grayscale image data (values 0-255)
const uint8_t image_data[IMAGE_WIDTH * IMAGE_HEIGHT] = {
    0,  32,  64,  96, 128, 160, 192, 224,
   32,  64,  96, 128, 160, 192, 224, 255,
   64,  96, 128, 160, 192, 224, 255, 224,
   96, 128, 160, 192, 224, 255, 224, 192,
  128, 160, 192, 224, 255, 224, 192, 160,
  160, 192, 224, 255, 224, 192, 160, 128,
  192, 224, 255, 224, 192, 160, 128,  96,
  224, 255, 224, 192, 160, 128,  96,  64
};

#endif // IMAGE_DATA_H
