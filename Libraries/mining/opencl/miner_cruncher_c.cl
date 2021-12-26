#include "Libraries/mining/opencl/includes/inc_vendor.h"
#include "Libraries/mining/opencl/includes/inc_types.h"
#include "Libraries/mining/opencl/includes/inc_platform.cl"
#include "Libraries/mining/opencl/includes/inc_common.cl"
#include "Libraries/mining/opencl/includes/inc_simd.cl"
#include "Libraries/mining/opencl/includes/inc_hash_sha256.cl"

# define HEAD1_SIZE_WORDS 2
# define HEAD1_SIZE_BYTES 7
# define HEAD2_SIZE_WORDS 14
# define HEAD2_SIZE_BYTES 56
# define RAND_SIZE_WORDS 6
# define RAND_SIZE_BYTES 24
# define SEED_SIZE_WORDS 4
# define SEED_SIZE_BYTES 16
# define WORK_SIZE_WORDS 14
# define WORK_SIZE_BYTES 56
# define TIME_INC_NUMBER 100

KERNEL_FQ void crunch(
        __global const u32x *data_head1,
        __global const u32x *data_head2,
        __global const u32x *data_rand,
        __global const u32x *data_seed,
        __global const u32x *time,
        __global const u32x *prefix,
        __global const u32x *data_check,
        __global const u32x *divider,
        __global u32x *abort,
        __global u32x *work,
        __global u32x *solution) {


    /**
    * Basics
    */
    const u32x gid = get_global_id (0);
    const u32x u32size = 4294967295;

    /**
    * Job parameterization
    */
    u32x timestamp[64] = { 0 };
    timestamp[0] = *time;
    const u32x iterations_max = u32size / divider[0];

    u32x prefix_offset;
    if (gid < divider[0]) {
        prefix_offset = 0;
    } else {
        prefix_offset = (gid - (gid % divider[0])) / divider[0];
    }
    u32x prefix_l = *prefix + prefix_offset;
    u32x count_start = iterations_max * (gid % divider[0]);

    u32x time_bump_loop = iterations_max / TIME_INC_NUMBER;

    /*
    printf("Job Parameters for vector %i:\n", gid);
    printf("    Size          : %lu\n", u32size);
    printf("    Divider       : %lu\n", divider[0]);
    printf("    Iterations max: %lu\n", iterations_max);
    printf("    Counter start : %lu\n", count_start);
    printf("    Time Bump loop: %lu\n", time_bump_loop);
    printf("    Time value    : %lu\n", timestamp[0]);
    printf("    Prefix offset : %lu\n", prefix_offset);
    printf("    Prefix value  : %lu\n", prefix_l);
    printf("    Data head1    : ");
    printf("%08x", data_head1[0]);
    printf("%08x", data_head1[1]);
    printf("\n");
    printf("    Data head2    : ");
    printf("%08x", data_head2[0]);
    printf("%08x", data_head2[1]);
    printf("%08x", data_head2[2]);
    printf("%08x", data_head2[3]);
    printf("%08x", data_head2[4]);
    printf("%08x", data_head2[5]);
    printf("%08x", data_head2[6]);
    printf("%08x", data_head2[7]);
    printf("%08x", data_head2[8]);
    printf("%08x", data_head2[9]);
    printf("%08x", data_head2[10]);
    printf("%08x", data_head2[11]);
    printf("%08x", data_head2[12]);
    printf("%08x", data_head2[13]);
    printf("\n");
    printf("    Data rand     : ");
    printf("%08x", data_rand[0]);
    printf("%08x", data_rand[1]);
    printf("%08x", data_rand[2]);
    printf("%08x", data_rand[3]);
    printf("%08x", data_rand[4]);
    printf("%08x", data_rand[5]);
    printf("\n");
    printf("    Data seed     : ");
    printf("%08x", data_seed[0]);
    printf("%08x", data_seed[1]);
    printf("%08x", data_seed[2]);
    printf("%08x", data_seed[3]);
    printf("\n");
    printf("    Complexity    : ");
    printf("%08x", data_check[0]);
    printf("%08x", data_check[1]);
    printf("%08x", data_check[2]);
    printf("%08x", data_check[3]);
    printf("%08x", data_check[4]);
    printf("%08x", data_check[5]);
    printf("%08x", data_check[6]);
    printf("%08x", data_check[7]);
    printf("\n");
    */

    /**
    * Workload
    */
    u32x w[64] = { 0 };
    w[0] = prefix_l;
    w[1] = count_start;
    w[2] = data_seed[0];
    w[3] = data_seed[1];
    w[4] = data_seed[2];
    w[5] = data_seed[3];
    w[6] = data_rand[0];
    w[7] = data_rand[1];
    w[8] = data_rand[2];
    w[9] = data_rand[3];
    w[10] = data_rand[4];
    w[11] = data_rand[5];
    w[12] = prefix_l;
    w[13] = count_start;

    sha256_ctx_t shactx1;
    sha256_ctx_t shactx2;
    sha256_init (&shactx1);
    sha256_update_global (&shactx1, data_head1, HEAD1_SIZE_BYTES);
    sha256_update (&shactx1, timestamp, 4);
    sha256_update_global (&shactx1, data_head2, HEAD2_SIZE_BYTES);

    u32x iterations_counter;
    u32x time_bump_counter = 0;
    for (iterations_counter = 0; iterations_counter < iterations_max; iterations_counter++) {
        if (abort[0]) {
            //printf("Thread %i breaking off after %i iterations.\n", gid, iterations_counter);
            break;
        }
        if (time_bump_counter == time_bump_loop) {
            timestamp[0]++;
            sha256_init (&shactx1);
            sha256_update_global (&shactx1, data_head1, HEAD1_SIZE_BYTES);
            sha256_update (&shactx1, timestamp, 4);
            sha256_update_global (&shactx1, data_head2, HEAD2_SIZE_BYTES);
            time_bump_counter = 0;
        } else {
            time_bump_counter++;
        }

        shactx2 = shactx1;
        sha256_update (&shactx2, w, WORK_SIZE_BYTES);
        sha256_final (&shactx2);

        if (
            (shactx2.h[0] == 0 && data_check[0] == 0 && shactx2.h[1] < data_check[1])
            || shactx2.h[0] < data_check[0]
            ) {
            // ATTENTION! Keep this loop here, I know it makes no sense
            // whatsoever but it does speed up the hashrate.... :/
            for (int t = 0; t < 8; t++) {
                solution[t] = shactx2.h[t];
            }
            /*
            printf("Hit Digest %i:\n", gid);
            for (int t = 0; t < 8; t++) {
                printf(" %08x\n", shactx2.h[t]);
            }
            printf("\n");
            */

            abort[0] = 1;

            for (int t = 0; t < HEAD1_SIZE_WORDS; t++) {
                solution[t] = data_head1[t];
            }
            solution[HEAD1_SIZE_WORDS] = timestamp[0];
            for (int t = 0; t < HEAD2_SIZE_WORDS; t++) {
                solution[HEAD1_SIZE_WORDS+1+t] = data_head2[t];
            }

            for (int t = 0; t < WORK_SIZE_WORDS; t++) {
                solution[HEAD1_SIZE_WORDS+1+HEAD2_SIZE_WORDS+t] = w[t];
            }
            break;
        }

        w[1]++;
        w[13]++;
    }

    work[gid] = iterations_counter;
}
