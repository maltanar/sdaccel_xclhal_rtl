#include <assert.h>
#include <stdio.h>
#include <xclhal2.h>
#include "xclhal_utils.h"

// A very thin wrapper around XCL HAL calls for low-level device access

xclDeviceHandle hDevice;
// base address for user logic AXI lite
const unsigned long long int csr_base = 0x1800000; // 0x1800000 for real hw, 0 for hw_emu?
// base address for DRAM buffers on device memory
const unsigned long long int dram_base = 0x000000000;
// buffer for reading xclbin into host memory
unsigned char *kernelbinary;

// Helper function to load xclbin file to memory from SDAccel examples
int load_file_to_memory(const char *filename, char **result)
{
    uint size = 0;
    FILE *f = fopen(filename, "rb");
    if (f == NULL) {
        *result = NULL;
        return -1;
    }
    fseek(f, 0, SEEK_END);
    size = ftell(f);
    fseek(f, 0, SEEK_SET);
    // allocate enough memory to hold the xclbin
    *result = (char *)malloc(size+1);
    if (size != fread(*result, sizeof(char), size, f)) {
        free(*result);
        return -2;
    }
    fclose(f);
    (*result)[size] = 0;
    return size;
}

void init(const char * xclbin) {
  // make sure there is at least one device available
  assert(xclProbe() >= 1);
  // open and get exclusive access to the device
  hDevice = xclOpen(0, "xcl.log", XCL_QUIET);
  xclLockDevice(hDevice);
  // load the xclbin contents into memory
	int n_i0 = load_file_to_memory(xclbin, (char **) &kernelbinary);
	assert(n_i0 >= 0);
	// load the xclbin into the device
	xclLoadXclBin(hDevice, (const xclBin*)kernelbinary);
}

void deinit() {
  xclUnlockDevice(hDevice);
  xclClose(hDevice);
  free(kernelbinary);
}

const uint32_t readReg32(const uint64_t reg_offset) {
  uint32_t ret = 0;
  size_t nret = xclRead(hDevice, XCL_ADDR_KERNEL_CTRL, csr_base + reg_offset, (void*)&ret, 4);
  assert(nret == 4);
  return ret;
}

void writeReg32(const uint64_t reg_offset, const uint32_t value) {
  size_t nret = xclWrite(hDevice, XCL_ADDR_KERNEL_CTRL, csr_base + reg_offset, (void*)&value, sizeof(unsigned int));
  assert(nret == sizeof(unsigned int));
}

const uint64_t readReg64(const uint64_t reg_offset) {
  uint64_t ret = readReg32(reg_offset);
  ret |= (uint64_t)readReg32(reg_offset + 0x4) << 32;
  return ret;
}

void writeReg64(const uint64_t reg_offset, const uint64_t value) {
  writeReg32(reg_offset, (uint32_t)(value & 0xffffffff));
  writeReg32(reg_offset + 0x4, (uint32_t)((value >> 32) & 0xffffffff));
}

void readDRAM(const uint64_t dram_offset, void * buf, const size_t nbytes) {
  int nret = xclUnmgdPread(hDevice, 0, buf, nbytes, dram_base + dram_offset);
  //size_t nret = xclRead(hDevice, XCL_ADDR_SPACE_DEVICE_RAM, dram_base + dram_offset, buf, nbytes);
  // xclUnmgd* does not seem to return number of read/written bytes; just <0 for errors
  assert(nret >= 0);
}

void writeDRAM(const uint64_t dram_offset, const void * buf, const size_t nbytes) {
  int nret = xclUnmgdPwrite(hDevice, 0, buf, nbytes, dram_base + dram_offset);
  //int nret = xclWrite(hDevice, XCL_ADDR_SPACE_DEVICE_RAM, dram_base + dram_offset, buf, nbytes);
  // xclUnmgd* does not seem to return number of read/written bytes; just <0 for errors  
  assert(nret >= 0);
}
