#include <stdint.h>

// Edge Detection Accelerator Registers
#define EDGE_CTRL_BASE  0x20000000

typedef struct {
    volatile uint32_t src_addr;   // 0x00 - Source image address
    volatile uint32_t dst_addr;   // 0x04 - Destination address
    volatile uint32_t width;      // 0x08 - Image width
    volatile uint32_t height;     // 0x0C - Image height
    volatile uint32_t enable;     // 0x10 - Enable accelerator
    volatile uint32_t start;      // 0x14 - Start processing (auto-clears)
    volatile uint32_t status;     // 0x18 - Status (bit 0 = done)
} edge_ctrl_t;

#define edge_ctrl ((edge_ctrl_t *)EDGE_CTRL_BASE)

// Simple test image (8x8 grayscale)
uint8_t test_image[64] = {
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00,
    0x00, 0xFF, 0x00, 0x00, 0x00, 0x00, 0xFF, 0x00,
    0x00, 0xFF, 0x00, 0xFF, 0xFF, 0x00, 0xFF, 0x00,
    0x00, 0xFF, 0x00, 0xFF, 0xFF, 0x00, 0xFF, 0x00,
    0x00, 0xFF, 0x00, 0x00, 0x00, 0x00, 0xFF, 0x00,
    0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

uint8_t output_image[64];

void edge_detect(uint32_t src, uint32_t dst, uint16_t width, uint16_t height) {
    // Set up accelerator
    edge_ctrl->src_addr = src;
    edge_ctrl->dst_addr = dst;
    edge_ctrl->width = width;
    edge_ctrl->height = height;
    edge_ctrl->enable = 1;
    
    // Start processing
    edge_ctrl->start = 1;
    
    // Wait for completion
    while (!(edge_ctrl->status & 0x1)) {
        // Can also use interrupts instead of polling
    }
}

int main() {
    // Copy test image to SRAM (address 0x10000000)
    uint8_t *sram = (uint8_t *)0x10000000;
    for (int i = 0; i < 64; i++) {
        sram[i] = test_image[i];
    }
    
    // Perform edge detection
    edge_detect(0x10000000, (uint32_t)output_image, 8, 8);
    
    // The output_image now contains the edge-detected version
    
    // Return success
    return 0;
}