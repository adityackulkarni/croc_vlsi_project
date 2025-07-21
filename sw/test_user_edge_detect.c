#include "uart.h"
#include "print.h"
#include "gpio.h"
#include "util.h"

#define TB_FREQUENCY     10000000
#define TB_BAUDRATE      115200

#define USER_EDGE_DETECT_BASE_ADDR 0x20000000

// MMIO offsets for input pixels
#define EDGE_DETECT_INPUT_BASE     0x0  // 9 bytes for 3x3 pixels (0x0,0x4,0x8,...)
#define EDGE_DETECT_START_OFFSET   0x24
#define EDGE_DETECT_STATUS_OFFSET  0x28
#define EDGE_DETECT_RESULT_OFFSET  0x4

uint8_t get_pixel_center(uint8_t window[3][3]) {
    return window[1][1];
}

int main() {
    uart_init();

    printf("=== Starting Edge Detection Test ===\n");
    uart_write_flush();

    uint8_t test_windows[8][3][3] = {
        {{ 10,  10,  10}, { 10,  10,  10}, { 10,  10,  10}},
        {{  0, 255,   0}, {255,   0, 255}, {  0, 255,   0}},
        {{  0,  50, 100}, {150, 200, 250}, {255, 255, 255}},
        {{255, 255, 255}, {255,   0, 255}, {255, 255, 255}},
        {{  0,   0,   0}, {  0, 255,   0}, {  0,   0,   0}},
        {{100, 150, 100}, {150, 255, 150}, {100, 150, 100}},
        {{  0, 100,   0}, {100, 255, 100}, {  0, 100,   0}},
        {{255, 128,   0}, {128,   0, 128}, {  0, 128, 255}}
    };

    uint8_t hardware_results[8];

    for (int i = 0; i < 8; i++) {
        // Write the 3x3 pixel window to hardware at offsets 0x0 to 0x20 (each pixel 1 byte)
        // Assuming 32-bit writes with padding: write each pixel to 4-byte aligned addresses for simplicity
        int idx = 0;
        for (int r = 0; r < 3; r++) {
            for (int c = 0; c < 3; c++) {
                *(volatile uint32_t*)(USER_EDGE_DETECT_BASE_ADDR + EDGE_DETECT_INPUT_BASE + idx*4) = (uint32_t)test_windows[i][r][c];
                idx++;
            }
        }

        // Trigger computation by writing 1 to start register at 0x24
        *(volatile uint32_t*)(USER_EDGE_DETECT_BASE_ADDR + EDGE_DETECT_START_OFFSET) = 1;

        // Wait for done status bit at 0x28
        int timeout = 100000;
        while ((*(volatile uint32_t*)(USER_EDGE_DETECT_BASE_ADDR + EDGE_DETECT_STATUS_OFFSET) == 0) && (timeout-- > 0));

        if (timeout <= 0) {
            printf("HW Test %d: ERROR: Timeout waiting for accelerator\n", i);
            hardware_results[i] = 0xFF; // mark as failed
            continue;
        }

        // Read result at 0x4
        hardware_results[i] = (uint8_t)(*(volatile uint32_t*)(USER_EDGE_DETECT_BASE_ADDR + EDGE_DETECT_RESULT_OFFSET) & 0xFF);
        printf("HW Test %d: Result = %u\n", i, hardware_results[i]);
    }

    uart_write_flush();

    printf("=== Done ===\n");
    return 0;
}
