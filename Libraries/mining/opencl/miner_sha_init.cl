#include "Libraries/mining/opencl/includes/inc_vendor.h"
#include "Libraries/mining/opencl/includes/inc_types.h"
#include "Libraries/mining/opencl/includes/inc_platform.cl"
#include "Libraries/mining/opencl/includes/inc_common.cl"
#include "Libraries/mining/opencl/includes/inc_simd.cl"
#include "Libraries/mining/opencl/includes/inc_hash_sha256.cl"

# define HEAD_SIZE_WORDS 17
# define HEAD_SIZE_BYTES 67

KERNEL_FQ void init(
        __global const u32x *data,
        __global u32x *hash,
        __global u32x *w) {

    const u32x gid = get_global_id (0);

    /*
    printf("Job Parameters for vector %i:\n", gid);
    printf("    Size Words    : %lu\n", HEAD_SIZE_WORDS);
    printf("    Size Bytes    : %lu\n", HEAD_SIZE_BYTES);
    printf("    Data          : ");
    for (int t = 0; t < HEAD_SIZE_WORDS; t++) {
        printf("%08x", data[t]);
    }
    printf("\n");
    */

    /**
    * Work
    */
    sha256_ctx_t shactx1;
    sha256_init (&shactx1);
    sha256_update_global (&shactx1, data, HEAD_SIZE_BYTES);

    /**
    * Payload return
    */
    for (int t = 0; t < 8; t++) {
        hash[t] = shactx1.h[t];
    }
    w[0] = shactx1.w0[0];
    /*
    for (int t = 0; t < 4; t++) {
        w[0+t] = shactx1.w0[t];
    }
    for (int t = 0; t < 4; t++) {
        w[4+t] = shactx1.w1[t];
    }
    for (int t = 0; t < 4; t++) {
        w[8+t] = shactx1.w2[t];
    }
    for (int t = 0; t < 4; t++) {
        w[12+t] = shactx1.w3[t];
    }
    */

    /*
    printf("Job Results for vector %i:\n", gid);
    printf("    Len           : %lu\n", shactx1.len);
    printf("    Hash          : ");
    printf("%08x", shactx1.h[0]);
    printf("%08x", shactx1.h[1]);
    printf("%08x", shactx1.h[2]);
    printf("%08x", shactx1.h[3]);
    printf("%08x", shactx1.h[4]);
    printf("%08x", shactx1.h[5]);
    printf("%08x", shactx1.h[6]);
    printf("%08x", shactx1.h[7]);
    printf("\n");
    printf("    W0            : ");
    printf("%08x", shactx1.w0[0]);
    printf("%08x", shactx1.w0[1]);
    printf("%08x", shactx1.w0[2]);
    printf("%08x", shactx1.w0[3]);
    printf("\n");
    printf("    W1            : ");
    printf("%08x", shactx1.w1[0]);
    printf("%08x", shactx1.w1[1]);
    printf("%08x", shactx1.w1[2]);
    printf("%08x", shactx1.w1[3]);
    printf("\n");
    printf("    W2            : ");
    printf("%08x", shactx1.w2[0]);
    printf("%08x", shactx1.w2[1]);
    printf("%08x", shactx1.w2[2]);
    printf("%08x", shactx1.w2[3]);
    printf("\n");
    printf("    W3            : ");
    printf("%08x", shactx1.w3[0]);
    printf("%08x", shactx1.w3[1]);
    printf("%08x", shactx1.w3[2]);
    printf("%08x", shactx1.w3[3]);
    printf("\n");
    */
}
