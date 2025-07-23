oseda-2025.01:[sw]$ make bin/test.elf
riscv64-unknown-elf-gcc -march=rv32i_zicsr -mabi=ilp32 -mcmodel=medany -static -std=gnu99 -Os -nostdlib -fno-builtin -ffreestanding -Iinclude -Ilib/inc -I/scratch/vlsi2_21fs25/croc_vlsi_project/sw -c test.c -o test.c.o
test.c: In function 'main':
test.c:20:5: error: implicit declaration of function 'timer_init' [-Wimplicit-function-declaration]
   20 |     timer_init();
      |     ^~~~~~~~~~
test.c:32:19: error: implicit declaration of function 'timer_time_us' [-Wimplicit-function-declaration]
   32 |     uint32_t t0 = timer_time_us();
      |                   ^~~~~~~~~~~~~
test.c:44:6: error: implicit declaration of function 'reg32' [-Wimplicit-function-declaration]
   44 |     *reg32(REG_CURRENT_ADDR) = (uint32_t) IMG_BASE_ADDR;
      |      ^~~~~
test.c:44:5: error: invalid type argument of unary '*' (have 'int')
   44 |     *reg32(REG_CURRENT_ADDR) = (uint32_t) IMG_BASE_ADDR;
      |     ^~~~~~~~~~~~~~~~~~~~~~~~
test.c:45:5: error: invalid type argument of unary '*' (have 'int')
   45 |     *reg32(REG_IMG_SIZE)     = IMAGE_SIZE;
      |     ^~~~~~~~~~~~~~~~~~~~
test.c:46:5: error: invalid type argument of unary '*' (have 'int')
   46 |     *reg32(REG_THRESHOLD)    = THRESHOLD;
      |     ^~~~~~~~~~~~~~~~~~~~~
test.c:47:5: error: invalid type argument of unary '*' (have 'int')
   47 |     *reg32(REG_START)        = 1; // start FSM
      |     ^~~~~~~~~~~~~~~~~
test.c:51:13: error: invalid type argument of unary '*' (have 'int')
   51 |     while ((*reg32(REG_DONE) & 0x1) == 0) {}
      |             ^~~~~~~~~~~~~~~~
make: *** [Makefile:58: test.c.o] Error 1
