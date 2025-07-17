#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#define SRAM_BASE        0x10000000
#define EDGE_ACCEL_BASE  0x20000000

#define TEST_ADDR_OFFSET 0x00000004  // Any aligned offset
#define TEST_ADDR        (SRAM_BASE + TEST_ADDR_OFFSET)

int main() {
    volatile uint32_t* sram_ptr   = (uint32_t*) TEST_ADDR;
    volatile uint32_t* accel_ptr  = (uint32_t*) (EDGE_ACCEL_BASE + TEST_ADDR_OFFSET);

    // Step 1: Write known test data to SRAM
    *sram_ptr = 0xAAAAAAAA;
    printf("Wrote 0x%08X to SRAM at 0x%08X\n", *sram_ptr, TEST_ADDR);

    // Step 2: Trigger accelerator with read (this starts processing)
    uint32_t result = *accel_ptr;
    printf("Accelerator processed data: 0x%08X\n", result);

    // Step 3: Read back from SRAM directly
    uint32_t final = *sram_ptr;
    printf("SRAM final value: 0x%08X\n", final);

    // Step 4: Check expected result
    if (final == 0x55555555) {
        printf("[PASS] Result is as expected.\n");
        return 0;
    } else {
        printf("[FAIL] Expected 0x55555555, got 0x%08X\n", final);
        return 1;
    }
}
