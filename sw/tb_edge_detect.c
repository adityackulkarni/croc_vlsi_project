// Steps

// 1. It runs the Sobel filter on the same 3x3 image patch:

// 2. Once in software for reference

// 3. Once on hardware accelerator for speed and correctness

// 4. It times both implementations using cycle counters.

// 5. It copies image data to SRAM for accelerator access.

// 6. It uses MMIO registers to communicate with the accelerator.

// 7. It prints results and compares software and hardware outputs.

// 8. It checks if the results match and prints a message accordingly.


// tb_edge_detect.c

// Testbench for edge detection using Sobel filter
// This code runs a Sobel filter on a 3x3 image patch in both software and hardware

#include <stdint.h>
#include "lib/inc/uart.h"
#include "lib/inc/print.h"
#include "lib/inc/timer.h"
#include "image_data.h"

#define SRAM_ADDR   ((volatile uint8_t *) 0x10000000)

// Accelerator MMIO addresses
#define ACCEL_BASE    0x20000000
#define ACCEL_START   (*(volatile uint32_t *)(ACCEL_BASE + 0x00))
#define ACCEL_DONE    (*(volatile uint32_t *)(ACCEL_BASE + 0x04))
#define ACCEL_MATCH   (*(volatile uint32_t *)(ACCEL_BASE + 0x08))

// 3x3 Sobel kernel (horizontal)
const int8_t filter[9] = {
    -1, 0, 1,
    -2, 0, 2,
    -1, 0, 1
};

int software_sobel(const uint8_t* image) {
    int sum = 0;
    for (int i = 0; i < 9; i++) {
        sum += filter[i] * image[i];
    }
    return sum;
}

int main() {
    uart_init();
    uart_write_flush();
    printf("===== Croc Edge Detection Test =====\n");

    // Copy image data into SRAM (accelerator will read from here)
    for (int i = 0; i < 9; i++) {
        SRAM_ADDR[i] = image_data[i];
    }

    // --- Software version ---
    printf("\n[Software] Starting Sobel filter...\n");
    uint32_t sw_start = get_mcycle();
    int result = software_sobel(image_data);
    int sw_match = result > 100;
    uint32_t sw_end = get_mcycle();
    printf("[Software] Result: %d (match: %d)\n", result, sw_match);
    printf("[Software] Cycles: %lu\n", sw_end - sw_start);

    // --- Accelerator version ---
    printf("\n[Accelerator] Starting hardware accelerator...\n");
    uint32_t hw_start = get_mcycle();

    ACCEL_START = 1;  // Trigger accelerator

    // Wait until accelerator sets 'done'
    while (ACCEL_DONE == 0);

    uint32_t hw_end = get_mcycle();
    int hw_match = ACCEL_MATCH;

    printf("[Accelerator] Match: %d\n", hw_match);
    printf("[Accelerator] Cycles: %lu\n", hw_end - hw_start);

    // --- Comparison ---
    if (sw_match == hw_match) {
        printf("\n Match: Software and Accelerator results agree\n");
    } else {
        printf("\n Mismatch: Software and Accelerator results differ\n");
    }

    return 0;
}
