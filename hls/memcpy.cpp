#include <ap_int.h>

ap_int<32> memcpy(ap_int<32> *src, ap_int<32> *dst, unsigned int nwords) {
#pragma HLS INTERFACE m_axi port=src  offset=slave bundle=gmem
#pragma HLS INTERFACE m_axi port=dst  offset=slave bundle=gmem
#pragma HLS INTERFACE s_axilite port=src  bundle=control
#pragma HLS INTERFACE s_axilite port=dst bundle=control
#pragma HLS INTERFACE s_axilite port=nwords bundle=control
#pragma HLS INTERFACE s_axilite port=return bundle=control

  ap_int<32> sum = 0;
  for(unsigned int i = 0; i < nwords; i++) {
    ap_int<32> c = src[i];
    dst[i] = c;
    sum += c;
  }
  return sum;
}
