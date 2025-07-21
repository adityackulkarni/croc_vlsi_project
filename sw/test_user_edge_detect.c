// Copyright (c) 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0/
//
// Authors:
// - Philippe Sauter <phsauter@iis.ee.ethz.ch>

#include "uart.h"
#include "print.h"
#include "util.h"

#define TB_FREQUENCY     10000000
#define TB_BAUDRATE      115200

// Real base address of user_edge_detect accelerator
#define USER_EDGE_DETECT_BASE_ADDR 0x20000000


// Offsets for registers in the edge detection accelerator
#define EDGE_DETECT_INPUT_OFFSET   0x0  // Write input pixel (grayscale, 8-bit in LSB)
#define EDGE_DETECT_START_OFFSET   0x4  // Write 1 to start processing
#define EDGE_DETECT_STATUS_OFFSET  0x8  // Read status: 0 = busy, 1 = done
#define EDGE_DETECT_RESULT_OFFSET  0xC  // Read edge detected result (8-bit)

// Sobel kernels
const int8_t Gx[3][3] = {
    {-1, 0, 1},
    {-2, 0, 2},
    {-1, 0, 1}
};

const int8_t Gy[3][3] = {
    { 1,  2,  1},
    { 0,  0,  0},
    {-1, -2, -1}
};

// Clamp to [0,255]
static inline uint8_t clamp_int_to_uint8(int val) {
    if (val < 0) return 0;
    if (val > 255) return 255;
    return (uint8_t)val;
}

// Compute Sobel edge magnitude for 3x3 window of grayscale pixels
uint8_t sobel_edge_3x3(uint8_t window[3][3]) {
    int gx = 0, gy = 0;
    for (int r = 0; r < 3; r++) {
        for (int c = 0; c < 3; c++) {
            gx += window[r][c] * Gx[r][c];
            gy += window[r][c] * Gy[r][c];
        }
    }
    int mag = (gx*gx + gy*gy); // squared magnitude
    // Approximate sqrt with shift (simple)
    mag = (int)(sqrt((float)mag));
    return clamp_int_to_uint8(mag);
}

int main() {
    uart_init();

    printf("Starting Edge Detection Test\n");
    uart_write_flush();

    // Example 3x3 grayscale pixel windows for 8 test cases
    uint8_t test_windows[8][3][3] = {
        {{ 10,  10,  10}, { 10,  10,  10}, { 10,  10,  10}}, // uniform low
        {{  0, 255,   0}, {255,   0, 255}, {  0, 255,   0}}, // checker pattern
        {{  0,  50, 100}, {150, 200, 250}, {255, 255, 255}}, // gradient
        {{255, 255, 255}, {255,   0, 255}, {255, 255, 255}}, // single black pixel center
        {{  0,   0,   0}, {  0, 255,   0}, {  0,   0,   0}}, // single white pixel center
        {{100, 150, 100}, {150, 255, 150}, {100, 150, 100}}, // blurred edge
        {{  0, 100,   0}, {100, 255, 100}, {  0, 100,   0}}, // another pattern
        {{255, 128,   0}, {128,   0, 128}, {  0, 128, 255}}  // diagonal gradient
    };

    uint8_t software_results[8];
    uint8_t hardware_results[8];

    // Compute software results with Sobel
    for (int i = 0; i < 8; i++) {
        software_results[i] = sobel_edge_3x3(test_windows[i]);
    }

    // Run hardware accelerator on center pixel (assumed single 8-bit grayscale pixel input)
    // For test simplicity, we only send the center pixel value to the hardware
    for (int i = 0; i < 8; i++) {
        uint8_t center_pixel = test_windows[i][1][1];
        // Write input pixel to hardware (32-bit write, pixel in LSB)
        *(volatile uint32_t*)(USER_EDGE_DETECT_BASE_ADDR + EDGE_DETECT_INPUT_OFFSET) = (uint32_t)center_pixel;
        // Start processing
        *(volatile uint32_t*)(USER_EDGE_DETECT_BASE_ADDR + EDGE_DETECT_START_OFFSET) = 1;

        // Wait until done
        while (*(volatile uint32_t*)(USER_EDGE_DETECT_BASE_ADDR + EDGE_DETECT_STATUS_OFFSET) == 0) {
            // busy wait
        }

        // Read result (assumed 8-bit edge magnitude)
        hardware_results[i] = (uint8_t)*(volatile uint32_t*)(USER_EDGE_DETECT_BASE_ADDR + EDGE_DETECT_RESULT_OFFSET);
    }

    // Print comparison
    for (int i = 0; i < 8; i++) {
        printf("Test %d: Software = %3u, Hardware = %3u, Center pixel = %3u\n",
               i, software_results[i], hardware_results[i], test_windows[i][1][1]);
    }

    uart_write_flush();

    return 0;
}
