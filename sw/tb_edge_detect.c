#include <stdint.h>
#include <stdio.h>

#define WIDTH      64
#define HEIGHT     64
#define IMG_SIZE   (WIDTH * HEIGHT)

// MMIO Register Map
#define SOBEL_BASE         0x20000000
#define SOBEL_IN_ADDR      (*(volatile uint32_t *)(SOBEL_BASE + 0x00))
#define SOBEL_OUT_ADDR     (*(volatile uint32_t *)(SOBEL_BASE + 0x04))
#define SOBEL_IMG_SIZE     (*(volatile uint32_t *)(SOBEL_BASE + 0x08))
#define SOBEL_START        (*(volatile uint32_t *)(SOBEL_BASE + 0x0C))
#define SOBEL_DONE         (*(volatile uint32_t *)(SOBEL_BASE + 0x10))

// Buffers in main memory
uint8_t input_img[IMG_SIZE];
uint8_t sw_output[IMG_SIZE];
uint8_t hw_output[IMG_SIZE];

// Read 32-bit cycle counter
static inline uint32_t rdcycle() {
    uint32_t value;
    asm volatile ("rdcycle %0" : "=r"(value));
    return value;
}

// Simple software Sobel filter (no borders)
void sobel_sw(uint8_t *in, uint8_t *out, int w, int h) {
    int gx, gy;
    for (int y = 1; y < h - 1; ++y) {
        for (int x = 1; x < w - 1; ++x) {
            int idx = y * w + x;

            gx = -in[(y-1)*w + (x-1)] - 2*in[y*w + (x-1)] - in[(y+1)*w + (x-1)]
                 + in[(y-1)*w + (x+1)] + 2*in[y*w + (x+1)] + in[(y+1)*w + (x+1)];

            gy = -in[(y-1)*w + (x-1)] - 2*in[(y-1)*w + x] - in[(y-1)*w + (x+1)]
                 + in[(y+1)*w + (x-1)] + 2*in[(y+1)*w + x] + in[(y+1)*w + (x+1)];

            int mag = (gx * gx + gy * gy) >> 8;
            if (mag > 255) mag = 255;
            out[idx] = (uint8_t)mag;
        }
    }
}

// Compare images: count mismatches
int compare_images(uint8_t *a, uint8_t *b, int size) {
    int diff = 0;
    for (int i = 0; i < size; ++i) {
        if (a[i] != b[i]) {
            diff++;
        }
    }
    return diff;
}

int main() {
    // Initialize input with a known pattern
    for (int i = 0; i < IMG_SIZE; ++i) {
        input_img[i] = (uint8_t)(i % 256);
    }

    // Run software Sobel
    uint32_t sw_start = rdcycle();
    sobel_sw(input_img, sw_output, WIDTH, HEIGHT);
    uint32_t sw_end = rdcycle();
    uint32_t sw_cycles = sw_end - sw_start;

    // Run hardware Sobel
    uint32_t hw_start = rdcycle();
    SOBEL_IN_ADDR  = (uint32_t)input_img;
    SOBEL_OUT_ADDR = (uint32_t)hw_output;
    SOBEL_IMG_SIZE = (WIDTH << 16) | HEIGHT;
    SOBEL_START    = 1;
    while (SOBEL_DONE == 0);
    uint32_t hw_end = rdcycle();
    uint32_t hw_cycles = hw_end - hw_start;

    // Compare outputs
    int diff_pixels = compare_images(sw_output, hw_output, IMG_SIZE);

    // Print results
    printf("Software cycles: %u\n", sw_cycles);
    printf("Hardware cycles: %u\n", hw_cycles);

    if (hw_cycles > 0) {
        uint32_t speedup_int = sw_cycles / hw_cycles;
        uint32_t speedup_frac = (100 * sw_cycles / hw_cycles) % 100;
        printf("Speedup: %u.%02u x\n", speedup_int, speedup_frac);
    }

    if (diff_pixels == 0) {
        printf("Outputs match.\n");
    } else {
        printf("Outputs differ in %d pixels.\n", diff_pixels);
    }

    return 0;
}
