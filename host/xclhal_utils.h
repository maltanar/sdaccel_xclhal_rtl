#ifndef _UTILS_H_
#include <stdint.h>

// A very thin wrapper around XCL HAL calls for low-level device access

// init (load bitstream/xclbin) and deinit functions
void init(const char * xclbin);
void deinit();

// 32-bit user logic AXI-lite register reads and writes
const uint32_t readReg32(const uint64_t reg_offset);
void writeReg32(const uint64_t reg_offset, const uint32_t value);

// 64-bit user logic AXI-lite register reads and writes
// implemented as two consecutive 32-bit reads/writes
const uint64_t readReg64(const uint64_t reg_offset);
void writeReg64(const uint64_t reg_offset, const uint64_t value);

// copy buffers between host memory and device memory
void readDRAM(const uint64_t dram_offset, void * buf, const size_t nbytes);
void writeDRAM(const uint64_t dram_offset, const void * buf, const size_t nbytes);

#define _UTILS_H_
#endif // _UTILS_H_
