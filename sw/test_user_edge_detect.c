#include "uart.h"
#include "print.h"
#include "gpio.h"
#include "util.h"

#define TB_FREQUENCY 20000000
#define TB_BAUDRATE  115200

// Base address of edge detection accelerator (adjust accordingly)
#define USER_EDGE_DETECT_BASE_ADDR 0x20001000

// Offsets for accelerator registers (example)
#define EDGE_DETECT_PIXEL_OFFSET   0x00  // Write pixel value here (assume FIFO or 9 writes)
#define EDGE_DETECT_RESULT_OFFSET  0x08  // Read edge detection result here
#define EDGE_DETECT_STATUS_OFFSET  0x0C  // Read status: 1 = done, 0 = busy

// 3x3 windows to test (8 windows)
uint8_t windows[8][9] = {
    {0x00, 0x00, 0x00, 0x00, 0x10, 0x00, 0x00, 0x00, 0x00},
    {0x00, 0x00, 0x00, 0x10, 0x10, 0x10, 0x00, 0x00, 0x00},
    {0x00, 0x00, 0x00, 0x10, 0x80, 0x10, 0x00, 0x00, 0x00},
    {0x00, 0x00, 0x00, 0x10, 0x80, 0x10, 0x00, 0x00, 0x00},
    {0x00, 0x00, 0x00, 0x10, 0x40, 0x10, 0x00, 0x00, 0x00},
    {0x00, 0x00, 0x00, 0x00, 0x90, 0x00, 0x00, 0x00, 0x00},
    {0x00, 0x00, 0x00, 0x10, 0x90, 0x10, 0x00, 0x00, 0x00},
    {0x00, 0x00, 0x00, 0x10, 0x90, 0x10, 0x00, 0x00, 0x00}
};

// Simple software Sobel edge detection for 3x3 window
uint8_t sobel_software(uint8_t *w) {
    int gx = 0;
    int gy = 0;

    gx = (-1)*w[0] + 0*w[1] + (1)*w[2]
       + (-2)*w[3] + 0*w[4] + (2)*w[5]
       + (-1)*w[6] + 0*w[7] + (1)*w[8];

    gy = (-1)*w[0] + (-2)*w[1] + (-1)*w[2]
       + 0*w[3] + 0*w[4] + 0*w[5]
       + (1)*w[6] + (2)*w[7] + (1)*w[8];

    int abs_gx = gx < 0 ? -gx : gx;
    int abs_gy = gy < 0 ? -gy : gy;
    int g = abs_gx + abs_gy;

    if (g > 255) g = 255;

    return (uint8_t)g;
}


int main() {
    uart_init();
    printf("Edge detection accelerator test\n");

    uint32_t t0, t1, t2, t3;
    uint8_t sw_results[8];
    uint8_t hw_results[8];

    // Software edge detection timing
    asm volatile("csrr %0, mcycle" : "=r"(t0)::"memory");
    for (int i = 0; i < 8; i++) {
        sw_results[i] = sobel_software(windows[i]);
    }
    asm volatile("csrr %0, mcycle" : "=r"(t1)::"memory");

    // Hardware edge detection timing
    asm volatile("csrr %0, mcycle" : "=r"(t2)::"memory");
    for (int i = 0; i < 8; i++) {
        // Write all 9 pixels to accelerator
        for (int p = 0; p < 9; p++) {
            *reg32(USER_EDGE_DETECT_BASE_ADDR, EDGE_DETECT_PIXEL_OFFSET) = windows[i][p];
        }
        // Poll accelerator status for completion
        while (*reg32(USER_EDGE_DETECT_BASE_ADDR, EDGE_DETECT_STATUS_OFFSET) == 0) {
            // busy wait
        }
        // Read hardware result
        hw_results[i] = *reg32(USER_EDGE_DETECT_BASE_ADDR, EDGE_DETECT_RESULT_OFFSET);
    }
    asm volatile("csrr %0, mcycle" : "=r"(t3)::"memory");

    // Print results
    for (int i = 0; i < 8; i++) {
        printf("Window %d: SW %3d, HW %3d\n", i, sw_results[i], hw_results[i]);
    }

    printf("Software time: %d cycles\n", t1 - t0);
    printf("Hardware time: %d cycles\n", t3 - t2);

    uart_write_flush();
    return 0;
}
