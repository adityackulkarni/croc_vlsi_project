#include "/lib/inc/uart.h"
#include "/lib/inc/print.h"
#include "/lib/inc/timer.h"
#include "/lib/inc/mem.h"

#define IMG_BASE_ADDR    0x10000000  // SRAM0 base
#define ACC_BASE_ADDR    0x20000000  // Accelerator MMIO base

#define MMIO_ADDR        (*(volatile uint32_t*)(ACC_BASE_ADDR + 0x00))
#define MMIO_THRESH      (*(volatile uint32_t*)(ACC_BASE_ADDR + 0x04))
#define MMIO_START       (*(volatile uint32_t*)(ACC_BASE_ADDR + 0x08))
#define MMIO_IMG_SIZE    (*(volatile uint32_t*)(ACC_BASE_ADDR + 0x0C))

#define IMG_WIDTH        28
#define IMG_HEIGHT       28
#define IMG_PIXELS       (IMG_WIDTH * IMG_HEIGHT)
#define IMG_WORDS        (IMG_PIXELS / 4)

void write_test_image() {
    for (int i = 0; i < IMG_WORDS; ++i) {
        // Each word holds 4 pixels
        // We'll pack values: 50, 100, 150, 200 repeatedly
        uint8_t p1 = 50;
        uint8_t p2 = 100;
        uint8_t p3 = 150;
        uint8_t p4 = 200;
        uint32_t packed = (p4 << 24) | (p3 << 16) | (p2 << 8) | p1;
        ((volatile uint32_t*)IMG_BASE_ADDR)[i] = packed;
    }
}

void print_thresholded_image() {
    for (int i = 0; i < 8; ++i) {
        uint32_t word = ((volatile uint32_t*)IMG_BASE_ADDR)[i];
        uint8_t p1 = (word >> 0) & 0xFF;
        uint8_t p2 = (word >> 8) & 0xFF;
        uint8_t p3 = (word >> 16) & 0xFF;
        uint8_t p4 = (word >> 24) & 0xFF;
        printf("Word %d: %d %d %d %d\n", i, p1, p2, p3, p4);
    }
}

int main() {
    uart_init();
    printf("=== Thresholding Accelerator Test ===\n");

    // 1. Write test image to SRAM0
    printf("Writing test image to SRAM...\n");
    write_test_image();

    // 2. Configure MMIO
    printf("Configuring accelerator...\n");
    MMIO_ADDR     = IMG_BASE_ADDR;   // Address (word aligned)
    MMIO_THRESH   = 100;             // Threshold value
    MMIO_IMG_SIZE = IMG_PIXELS;      // Total pixels

    // 3. Start computation
    MMIO_START = 1;

    // 4. Wait (FIX THIS if you add a real "done" register)
    sleep_ms(10);

    // 5. Read back results
    printf("Result after thresholding:\n");
    print_thresholded_image();

    uart_write_flush();
    return 0;
}
