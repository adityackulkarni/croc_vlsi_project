#include "uart.h"
#include "print.h"
#include "timer.h"
#include "gpio.h"
#include "util.h"

#define IMG_WIDTH       28
#define IMG_HEIGHT      28
#define IMG_SIZE        (IMG_WIDTH * IMG_HEIGHT)

#define IMAGE_BASE_ADDR ((volatile uint8_t *)0x10000000)
#define OUTPUT_BASE_ADDR ((volatile uint16_t *)0x10000000) // same location for now

#define SOBEL_MMIO_BASE   0x20000000
#define SOBEL_MMIO_START  (*(volatile uint32_t *)(SOBEL_MMIO_BASE + 0x00))
#define SOBEL_MMIO_DONE   (*(volatile uint32_t *)(SOBEL_MMIO_BASE + 0x04))

int main() {
    uart_init();
    printf("Sobel Accelerator Test\n");
    uart_write_flush();

    // === 1. Fill image with test pattern ===
    printf("Writing test image to SRAM...\n");
    for (int i = 0; i < IMG_SIZE; i++) {
        IMAGE_BASE_ADDR[i] = (i % 256); // simple ramp pattern
    }
    uart_write_flush();

    // === 2. Start Accelerator ===
    printf("Starting accelerator...\n");
    uint32_t start = get_mcycle();
    SOBEL_MMIO_START = 1;

    // === 3. Wait for completion ===
    while (SOBEL_MMIO_DONE == 0) {
        asm volatile ("nop");
    }
    uint32_t end = get_mcycle();
    printf("Accelerator Done! Cycles: %u\n", end - start);
    uart_write_flush();

    // === 4. Read back and print output ===
    printf("Reading back output values (first 10 pixels):\n");
    for (int i = 0; i < 10; i++) {
        uint16_t val = OUTPUT_BASE_ADDR[i];
        printf("Pixel %d: %d\n", i, val);
    }
    uart_write_flush();

    return 0;
}
