#include <ap_int.h>

typedef enum {OP_ADD = 0, OP_SUB, OP_MUL} AluOpType;

ap_int<32> reg2reg(ap_int<32> opA, ap_int<32> opB, ap_uint<32> mode) {
#pragma HLS INTERFACE s_axilite port=opA  bundle=control
#pragma HLS INTERFACE s_axilite port=opB bundle=control
#pragma HLS INTERFACE s_axilite port=mode bundle=control
#pragma HLS INTERFACE s_axilite port=return bundle=control

	switch(mode) {
	case OP_ADD:
		return opA + opB;
		break;
	case OP_SUB:
		return opA - opB;
		break;
	case OP_MUL:
		return opA * opB;
		break;
	default:
		return 0xdeadbeef;
	}
}
