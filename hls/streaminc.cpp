#define AP_INT_MAX_W 8192
#include "ap_int.h"
#include "hls_stream.h"
using namespace hls;

void dmain(ap_int<32> *src, stream<ap_uint<32> > &output, unsigned int nwords) {
  for(unsigned int i = 0; i < nwords; i++) {
    output.write(src[i]);
  }
}

void dmaout(ap_int<32> *dst, stream<ap_uint<32> > &input, unsigned int nwords) {
  for(unsigned int i = 0; i < nwords; i++) {
    dst[i] = input.read();
  }
}

void dmainout(ap_int<32> *src, ap_int<32> *dst, stream<ap_uint<32> > &input, stream<ap_uint<32> > &output, unsigned int nwords) {
#pragma HLS INTERFACE m_axi port=src  offset=slave bundle=gmem
#pragma HLS INTERFACE m_axi port=dst  offset=slave bundle=gmem
#pragma HLS INTERFACE s_axilite port=src  bundle=control
#pragma HLS INTERFACE s_axilite port=dst bundle=control
#pragma HLS INTERFACE axis register both port=output
#pragma HLS INTERFACE axis register both port=input
#pragma HLS INTERFACE s_axilite port=nwords bundle=control
#pragma HLS INTERFACE s_axilite port=return bundle=control
#pragma HLS DATAFLOW
  dmain(src, output, nwords);
  dmaout(dst, input, nwords);
}

void streamadd(stream<ap_uint<32> > &input, stream<ap_uint<32> > &output){
#pragma HLS INTERFACE axis register both port=output
#pragma HLS INTERFACE axis register both port=input
#pragma HLS INTERFACE ap_ctrl_chain port=return
  ap_uint<32> inc;
  inc = input.read() + 1;
  output.write(inc);
}
