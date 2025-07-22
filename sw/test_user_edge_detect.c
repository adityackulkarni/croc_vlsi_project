#include "uart.h"
#include "print.h"
#include "gpio.h"
#include "util.h"

#define TB_FREQUENCY     20000000
#define TB_BAUDRATE      115200

#define USER_EDGE_DETECT_BASE_ADDR 0x20000000

#define EDGE_DETECT_START_OFFSET   0x4   // Write center pixel to start, read result
#define EDGE_DETECT_RESULT_OFFSET  0x4   // Same as start (readback)
#define EDGE_DETECT_STATUS_OFFSET  0x8   // Bit 0 = done

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

static inline uint8_t clamp_int_to_uint8(int val) {
    if (val < 0) return 0;
    if (val > 255) return 255;
    return (uint8_t)val;
}

uint8_t sobel_edge_3x3(uint8_t window[3][3]) {
    int gx = 0, gy = 0;
    for (int r = 0; r < 3; r++) {
        for (int c = 0; c < 3; c++) {
            gx += window[r][c] * Gx[r][c];
            gy += window[r][c] * Gy[r][c];
        }
    }
    int mag = (gx * gx + gy * gy);
    mag = (int)(mag >> 1);
    return clamp_int_to_uint8(mag);
}

int main() {
    uart_init();
    printf("=== Starting Edge Detection Test ===\n");

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

    uint8_t software_results[8];
    uint8_t hardware_results[8];

    printf("Calculating software results...\n");
    for (int i = 0; i < 8; i++) {
        software_results[i] = sobel_edge_3x3(test_windows[i]);
        printf("SW Test %x: Result = 0x%x\n", i, software_results[i]);
    }

    printf("Sending to hardware accelerator...\n");

    for (int i = 0; i < 8; i++) {
        uint8_t center_pixel = test_windows[i][1][1];
        printf("HW Test %x: Writing center pixel = 0x%x\n", i, center_pixel);

        // Start hardware computation by writing center pixel
        *(volatile uint32_t*)(USER_EDGE_DETECT_BASE_ADDR + EDGE_DETECT_START_OFFSET) = center_pixel;

        // Poll status until done
        int timeout = 500000;
        uint32_t status = 0;
        while (((status = *(volatile uint32_t*)(USER_EDGE_DETECT_BASE_ADDR + EDGE_DETECT_STATUS_OFFSET)) == 0) && timeout-- > 0) {
            if (timeout % 10000 == 0)
                printf("  ... waiting, status = 0x%x\n", status);
        }

        if (timeout <= 0) {
            printf("HW Test %x: ERROR: Timeout waiting for accelerator (status = 0x%x)\n", i, status);
            hardware_results[i] = 0xFF;
            continue;
        }

        // Read result
        hardware_results[i] = (uint8_t)*(volatile uint32_t*)(USER_EDGE_DETECT_BASE_ADDR + EDGE_DETECT_RESULT_OFFSET);
        printf("HW Test %x: Result = 0x%x\n", i, hardware_results[i]);
    }

    printf("Comparing results...\n");
    for (int i = 0; i < 8; i++) {
        printf("Test %x: SW = 0x%x, HW = 0x%x, Center = 0x%x\n",
               i, software_results[i], hardware_results[i], test_windows[i][1][1]);
    }

    printf("=== Done ===\n");
    return 0;
}
