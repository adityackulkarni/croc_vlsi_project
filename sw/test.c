#include "lib/inc/uart.h"
#include "lib/inc/print.h"
#include "lib/inc/timer.h"
#include "lib/inc/gpio.h"
#include "lib/inc/util.h"
#include "image_data.h" // defines `image_data` and `IMAGE_SIZE`

#define IMG_BASE_ADDR    0x10000000  // SRAM0 base
#define ACC_BASE_ADDR    0x20000000  // Accelerator MMIO base

#define REG_CURRENT_ADDR (0x00)
#define REG_THRESHOLD    (0x04)
#define REG_START        (0x08)
#define REG_IMG_SIZE     (0x0C)
#define REG_DONE         (0x10)  

// Threshold value to be applied
#define THRESHOLD 127

int main() {
    uart_init();

    printf("== Thresholding Comparison ==\n");

    volatile uint8_t *img_mem = (uint8_t *) IMG_BASE_ADDR;

    // 1. Copy image to SRAM
    for (int i = 0; i < IMAGE_SIZE; i++) {
        img_mem[i] = image_data[i];
    }
    uint32_t t0, t1, t2, t3;
    // 2. Software thresholding
    asm volatile("csrr %0, mcycle" : "=r"(t0)::"memory");
    for (int i = 0; i < IMAGE_SIZE; i++) {
        img_mem[i] = (image_data[i] > THRESHOLD) ? 255 : 0;
    }
    asm volatile("csrr %0, mcycle" : "=r"(t1)::"memory");

    // 3. Copy original image again (for hardware to use)
    for (int i = 0; i < IMAGE_SIZE; i++) {
        img_mem[i] = image_data[i];
    }

    // 4. Configure accelerator
    *reg32(ACC_BASE_ADDR, REG_CURRENT_ADDR) = (uint32_t) IMG_BASE_ADDR;
    *reg32(ACC_BASE_ADDR, REG_IMG_SIZE)     = IMAGE_SIZE;
    *reg32(ACC_BASE_ADDR, REG_THRESHOLD)    = THRESHOLD;
    *reg32(ACC_BASE_ADDR, REG_START)        = 1; // start FSM

    asm volatile("csrr %0, mcycle" : "=r"(t2)::"memory");
    // 5. Wait for accelerator to finish
    while ((*reg32(ACC_BASE_ADDR, REG_DONE) & 0x1) == 0) {}

    asm volatile("csrr %0, mcycle" : "=r"(t3)::"memory");

    // 6. Print results
    printf("Software done in %d us\n", t1 - t0);
    printf("Hardware done in %d us\n", t3 - t2);

    // 7. Validate result (optional)
    int errors = 0;
    for (int i = 0; i < IMAGE_SIZE; i++) {
        uint8_t expected = (image_data[i] > THRESHOLD) ? 255 : 0;
        if (img_mem[i] != expected) {
            errors++;
            if (errors <= 10) {
                printf("Mismatch at [%d]: got %d, expected %d\n", i, img_mem[i], expected);
            }
        }
    }

    if (errors == 0) {
        printf("✅ Accelerator output is correct!\n");
    } else {
        printf("❌ Accelerator output mismatch: %d errors\n", errors);
    }

    uart_write_flush();
    return 0;
}
