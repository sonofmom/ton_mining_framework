#include "Libraries/mining/opencl/includes/inc_vendor.h"
#include "Libraries/mining/opencl/includes/inc_types.h"
#include "Libraries/mining/opencl/includes/inc_platform.cl"
#include "Libraries/mining/opencl/includes/inc_common.cl"
#include "Libraries/mining/opencl/includes/inc_simd.cl"
#include "Libraries/mining/opencl/includes/inc_hash_sha256.cl"

# define HEAD_SIZE_WORDS 17
# define HEAD_SIZE_BYTES 67
# define RAND_SIZE_WORDS 6
# define RAND_SIZE_BYTES 24
# define SEED_SIZE_WORDS 4
# define SEED_SIZE_BYTES 16
# define WORK_SIZE_WORDS 14
# define WORK_SIZE_BYTES 56

#define ROUND_EXPAND_S()                            \
  {                                                   \
    w0_t = SHA256_EXPAND_S (we_t, w9_t, w1_t, w0_t);  \
    w1_t = SHA256_EXPAND_S (wf_t, wa_t, w2_t, w1_t);  \
    w2_t = SHA256_EXPAND_S (w0_t, wb_t, w3_t, w2_t);  \
    w3_t = SHA256_EXPAND_S (w1_t, wc_t, w4_t, w3_t);  \
    w4_t = SHA256_EXPAND_S (w2_t, wd_t, w5_t, w4_t);  \
    w5_t = SHA256_EXPAND_S (w3_t, we_t, w6_t, w5_t);  \
    w6_t = SHA256_EXPAND_S (w4_t, wf_t, w7_t, w6_t);  \
    w7_t = SHA256_EXPAND_S (w5_t, w0_t, w8_t, w7_t);  \
    w8_t = SHA256_EXPAND_S (w6_t, w1_t, w9_t, w8_t);  \
    w9_t = SHA256_EXPAND_S (w7_t, w2_t, wa_t, w9_t);  \
    wa_t = SHA256_EXPAND_S (w8_t, w3_t, wb_t, wa_t);  \
    wb_t = SHA256_EXPAND_S (w9_t, w4_t, wc_t, wb_t);  \
    wc_t = SHA256_EXPAND_S (wa_t, w5_t, wd_t, wc_t);  \
    wd_t = SHA256_EXPAND_S (wb_t, w6_t, we_t, wd_t);  \
    we_t = SHA256_EXPAND_S (wc_t, w7_t, wf_t, we_t);  \
    wf_t = SHA256_EXPAND_S (wd_t, w8_t, w0_t, wf_t);  \
}

KERNEL_FQ void crunch(
        __global const u32x *data_head,
        __global const u32x *data_rand,
        __global const u32x *data_seed,
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
    const u32x iterations_max = u32size / divider[0];

    u32x prefix_offset;
    if (gid < divider[0]) {
        prefix_offset = 0;
    } else {
        prefix_offset = (gid - (gid % divider[0])) / divider[0];
    }
    u32x prefix_l = *prefix + prefix_offset;
    u32x counter = iterations_max * (gid % divider[0]);

    /*
    printf("Job Parameters for vector %i:\n", gid);
    printf("    Size          : %lu\n", u32size);
    printf("    Divider       : %lu\n", divider[0]);
    printf("    Iterations max: %lu\n", iterations_max);
    printf("    Counter start : %lu\n", count_start);
    printf("    Prefix offset : %lu\n", prefix_offset);
    printf("    Prefix value  : %lu\n", prefix_l);
    printf("    Data head     : ");
    printf("%08x", data_head[0]);
    printf("%08x", data_head[1]);
    printf("%08x", data_head[2]);
    printf("%08x", data_head[3]);
    printf("%08x", data_head[4]);
    printf("%08x", data_head[5]);
    printf("%08x", data_head[6]);
    printf("%08x", data_head[7]);
    printf("%08x", data_head[8]);
    printf("%08x", data_head[9]);
    printf("%08x", data_head[10]);
    printf("%08x", data_head[11]);
    printf("%08x", data_head[12]);
    printf("%08x", data_head[13]);
    printf("%08x", data_head[14]);
    printf("%08x", data_head[15]);
    printf("%08x", data_head[16]);
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
    * Variables
    */
    u32x w0[4] = { 0 };
    u32x w1[4] = { 0 };
    u32x w2[4] = { 0 };
    u32x w3[4] = { 0 };
    u32x t0[4] = { 0 };
    u32x t1[4] = { 0 };
    u32x t2[4] = { 0 };
    u32x t3[4] = { 0 };
    u32x digest[8] = { 0 };
    u32 a,b,c,d,e,f,g,h;
    u32 w0_t,w1_t,w2_t,w3_t,w4_t,w5_t,w6_t,w7_t,w8_t,w9_t,wa_t,wb_t,wc_t,wd_t,we_t,wf_t;

    sha256_ctx_t ctx;
    sha256_init (&ctx);
    sha256_update_global (&ctx, data_head, HEAD_SIZE_BYTES);

    u32x iterations_counter;
    for (iterations_counter = 0; iterations_counter < iterations_max; iterations_counter++) {
        if (abort[0]) {
            //printf("Thread %i breaking off after %i iterations.\n", gid, iterations_counter);
            break;
        }

        t0[0] = ctx.w0[0];
        t0[1] = ctx.w0[1];
        t0[2] = ctx.w0[2];
        t0[3] = ctx.w0[3];
        t1[0] = ctx.w1[0];
        t1[1] = ctx.w1[1];
        t1[2] = ctx.w1[2];
        t1[3] = ctx.w1[3];
        t2[0] = ctx.w2[0];
        t2[1] = ctx.w2[1];
        t2[2] = ctx.w2[2];
        t2[3] = ctx.w2[3];
        t3[0] = ctx.w3[0];
        t3[1] = ctx.w3[1];
        t3[2] = ctx.w3[2];
        t3[3] = ctx.w3[3];

        digest[0] = ctx.h[0];
        digest[1] = ctx.h[1];
        digest[2] = ctx.h[2];
        digest[3] = ctx.h[3];
        digest[4] = ctx.h[4];
        digest[5] = ctx.h[5];
        digest[6] = ctx.h[6];
        digest[7] = ctx.h[7];

        w0[0] = prefix_l;
        w0[1] = counter;
        w0[2] = data_seed[0];
        w0[3] = data_seed[1];
        w1[0] = data_seed[2];
        w1[1] = data_seed[3];
        w1[2] = data_rand[0];
        w1[3] = data_rand[1];
        w2[0] = data_rand[2];
        w2[1] = data_rand[3];
        w2[2] = data_rand[4];
        w2[3] = data_rand[5];
        w3[0] = prefix_l;
        w3[1] = counter;
        w3[2] = 0x00000000;
        w3[3] = 0x00000000;
        switch_buffer_by_offset_be_S (w0, w1, w2, w3, 3);

        t0[0] |= w0[0];
        t0[1] |= w0[1];
        t0[2] |= w0[2];
        t0[3] |= w0[3];
        t1[0] |= w1[0];
        t1[1] |= w1[1];
        t1[2] |= w1[2];
        t1[3] |= w1[3];
        t2[0] |= w2[0];
        t2[1] |= w2[1];
        t2[2] |= w2[2];
        t2[3] |= w2[3];
        t3[0] |= w3[0];
        t3[1] |= w3[1];
        t3[2] |= w3[2];
        t3[3] |= w3[3];
        for (int t = 0; t < 4; t++) {
            printf("    t0[%i]     : %08x\n", t, t0[t]);
        }
        for (int t = 0; t < 4; t++) {
            printf("    t1[%i]     : %08x\n", t, t1[t]);
        }
        for (int t = 0; t < 4; t++) {
            printf("    t2[%i]     : %08x\n", t, t2[t]);
        }
        for (int t = 0; t < 4; t++) {
            printf("    t3[%i]     : %08x\n\n", t, t3[t]);
        }
        append_0x80_4x4_S (t0, t1, t2, t3, 56);
        for (int t = 0; t < 4; t++) {
            printf("    t0[%i]     : %08x\n", t, t0[t]);
        }
        for (int t = 0; t < 4; t++) {
            printf("    t1[%i]     : %08x\n", t, t1[t]);
        }
        for (int t = 0; t < 4; t++) {
            printf("    t2[%i]     : %08x\n", t, t2[t]);
        }
        for (int t = 0; t < 4; t++) {
            printf("    t3[%i]     : %08x\n", t, t3[t]);
        }
        printf("----\n");

        w0_t = t0[0];
        w1_t = t0[1];
        w2_t = t0[2];
        w3_t = t0[3];
        w4_t = t1[0];
        w5_t = t1[1];
        w6_t = t1[2];
        w7_t = t1[3];
        w8_t = t2[0];
        w9_t = t2[1];
        wa_t = t2[2];
        wb_t = t2[3];
        wc_t = t3[0];
        wd_t = t3[1];
        we_t = t3[2];
        wf_t = t3[3];

        a = digest[0];
        b = digest[1];
        c = digest[2];
        d = digest[3];
        e = digest[4];
        f = digest[5];
        g = digest[6];
        h = digest[7];

        SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w0_t, SHA256C00);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w1_t, SHA256C01);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, w2_t, SHA256C02);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, w3_t, SHA256C03);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, w4_t, SHA256C04);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, w5_t, SHA256C05);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, w6_t, SHA256C06);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, w7_t, SHA256C07);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w8_t, SHA256C08);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w9_t, SHA256C09);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, wa_t, SHA256C0a);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, wb_t, SHA256C0b);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, wc_t, SHA256C0c);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, wd_t, SHA256C0d);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, we_t, SHA256C0e);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, wf_t, SHA256C0f);
        ROUND_EXPAND_S()

        SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w0_t, SHA256C10);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w1_t, SHA256C11);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, w2_t, SHA256C12);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, w3_t, SHA256C13);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, w4_t, SHA256C14);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, w5_t, SHA256C15);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, w6_t, SHA256C16);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, w7_t, SHA256C17);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w8_t, SHA256C18);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w9_t, SHA256C19);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, wa_t, SHA256C1a);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, wb_t, SHA256C1b);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, wc_t, SHA256C1c);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, wd_t, SHA256C1d);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, we_t, SHA256C1e);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, wf_t, SHA256C1f);
        ROUND_EXPAND_S()

        SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w0_t, SHA256C20);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w1_t, SHA256C21);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, w2_t, SHA256C22);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, w3_t, SHA256C23);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, w4_t, SHA256C24);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, w5_t, SHA256C25);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, w6_t, SHA256C26);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, w7_t, SHA256C27);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w8_t, SHA256C28);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w9_t, SHA256C29);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, wa_t, SHA256C2a);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, wb_t, SHA256C2b);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, wc_t, SHA256C2c);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, wd_t, SHA256C2d);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, we_t, SHA256C2e);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, wf_t, SHA256C2f);
        ROUND_EXPAND_S()

        SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w0_t, SHA256C30);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w1_t, SHA256C31);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, w2_t, SHA256C32);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, w3_t, SHA256C33);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, w4_t, SHA256C34);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, w5_t, SHA256C35);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, w6_t, SHA256C36);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, w7_t, SHA256C37);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w8_t, SHA256C38);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w9_t, SHA256C39);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, wa_t, SHA256C3a);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, wb_t, SHA256C3b);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, wc_t, SHA256C3c);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, wd_t, SHA256C3d);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, we_t, SHA256C3e);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, wf_t, SHA256C3f);

        digest[0] += a;
        digest[1] += b;
        digest[2] += c;
        digest[3] += d;
        digest[4] += e;
        digest[5] += f;
        digest[6] += g;
        digest[7] += h;

        w0_t = 0;
        w1_t = 0;
        w2_t = 0;
        w3_t = 0;
        w4_t = 0;
        w5_t = 0;
        w6_t = 0;
        w7_t = 0;
        w8_t = 0;
        w9_t = 0;
        wa_t = 0;
        wb_t = 0;
        wc_t = 0;
        wd_t = 0;
        we_t = 0;
        wf_t = 0x000003d8;

        a = digest[0];
        b = digest[1];
        c = digest[2];
        d = digest[3];
        e = digest[4];
        f = digest[5];
        g = digest[6];
        h = digest[7];

        SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w0_t, SHA256C00);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w1_t, SHA256C01);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, w2_t, SHA256C02);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, w3_t, SHA256C03);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, w4_t, SHA256C04);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, w5_t, SHA256C05);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, w6_t, SHA256C06);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, w7_t, SHA256C07);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w8_t, SHA256C08);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w9_t, SHA256C09);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, wa_t, SHA256C0a);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, wb_t, SHA256C0b);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, wc_t, SHA256C0c);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, wd_t, SHA256C0d);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, we_t, SHA256C0e);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, wf_t, SHA256C0f);
        ROUND_EXPAND_S()

        SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w0_t, SHA256C10);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w1_t, SHA256C11);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, w2_t, SHA256C12);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, w3_t, SHA256C13);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, w4_t, SHA256C14);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, w5_t, SHA256C15);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, w6_t, SHA256C16);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, w7_t, SHA256C17);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w8_t, SHA256C18);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w9_t, SHA256C19);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, wa_t, SHA256C1a);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, wb_t, SHA256C1b);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, wc_t, SHA256C1c);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, wd_t, SHA256C1d);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, we_t, SHA256C1e);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, wf_t, SHA256C1f);
        ROUND_EXPAND_S()

        SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w0_t, SHA256C20);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w1_t, SHA256C21);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, w2_t, SHA256C22);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, w3_t, SHA256C23);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, w4_t, SHA256C24);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, w5_t, SHA256C25);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, w6_t, SHA256C26);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, w7_t, SHA256C27);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w8_t, SHA256C28);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w9_t, SHA256C29);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, wa_t, SHA256C2a);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, wb_t, SHA256C2b);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, wc_t, SHA256C2c);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, wd_t, SHA256C2d);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, we_t, SHA256C2e);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, wf_t, SHA256C2f);
        ROUND_EXPAND_S()

        SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w0_t, SHA256C30);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w1_t, SHA256C31);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, w2_t, SHA256C32);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, w3_t, SHA256C33);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, w4_t, SHA256C34);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, w5_t, SHA256C35);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, w6_t, SHA256C36);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, w7_t, SHA256C37);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w8_t, SHA256C38);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w9_t, SHA256C39);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, wa_t, SHA256C3a);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, wb_t, SHA256C3b);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, wc_t, SHA256C3c);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, wd_t, SHA256C3d);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, we_t, SHA256C3e);
        SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, wf_t, SHA256C3f);

        digest[0] += a;
        digest[1] += b;
        digest[2] += c;
        digest[3] += d;
        digest[4] += e;
        digest[5] += f;
        digest[6] += g;
        digest[7] += h;

        //if (
        //    (digest[0] == 0 && data_check[0] == 0 && digest[1] < data_check[1])
        //    || digest[0] < data_check[0]
        //    ) {
        if (iterations_counter == 0) {
            abort[0] = 1;

            for (int t = 0; t < HEAD_SIZE_WORDS; t++) {
                solution[t] = data_head[t];
            }
            solution[HEAD_SIZE_WORDS+0] = prefix_l;
            solution[HEAD_SIZE_WORDS+1] = counter;
            solution[HEAD_SIZE_WORDS+2] = data_seed[0];
            solution[HEAD_SIZE_WORDS+3] = data_seed[1];
            solution[HEAD_SIZE_WORDS+4] = data_seed[2];
            solution[HEAD_SIZE_WORDS+5] = data_seed[3];
            solution[HEAD_SIZE_WORDS+6] = data_rand[0];
            solution[HEAD_SIZE_WORDS+7] = data_rand[1];
            solution[HEAD_SIZE_WORDS+8] = data_rand[2];
            solution[HEAD_SIZE_WORDS+9] = data_rand[3];
            solution[HEAD_SIZE_WORDS+10] = data_rand[4];
            solution[HEAD_SIZE_WORDS+11] = data_rand[5];
            solution[HEAD_SIZE_WORDS+12] = prefix_l;
            solution[HEAD_SIZE_WORDS+13] = counter;

            break;
        }

        counter++;
    }

    work[gid] = iterations_counter;


    /**
    * Workload
    */
    /*
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
    sha256_update_global (&shactx1, data_head, HEAD_SIZE_BYTES);

    u32x iterations_counter, found;
    for (iterations_counter = 0; iterations_counter < iterations_max; iterations_counter++) {
        if (abort[0]) {
            //printf("Thread %i breaking off after %i iterations.\n", gid, iterations_counter);
            break;
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
            abort[0] = 1;

            for (int t = 0; t < HEAD_SIZE_WORDS; t++) {
                solution[t] = data_head[t];
            }
            for (int t = 0; t < WORK_SIZE_WORDS; t++) {
                solution[HEAD_SIZE_WORDS+t] = w[t];
            }
            break;
        }

        w[1]++;
        w[13]++;
    }

    work[gid] = iterations_counter;
    */


    /*
    sha256_ctx_t shactx3;
    sha256_init (&shactx3);

    u32x x[64] = { 0 };
    x[0] = 0x61616161;
    x[1] = 0x62626262;
    x[2] = 0x63636363;
    x[3] = 0x64646464;
    x[4] = 0x65656565;
    x[5] = 0x66666666;
    x[6] = 0x67676767;
    x[7] = 0x68686868;
    x[8] = 0x69696969;
    x[9] = 0x6a6a6a6a;
    x[10] = 0x6b6b6b6b;
    x[11] = 0x6c6c6c6c;
    x[12] = 0x6d6d6d6d;
    x[13] = 0x6e6e6e6e;
    x[14] = 0x6f6f6f6f;
    x[15] = 0x70707070;
    x[16] = 0x71717100;
    sha256_update (&shactx3, x, 67);
    printf("UPDATE 1 FINISH\n");
    printf("**************************************************************************\n");
    */

    /*
    u32x y[64] = { 0 };
    y[0] = 0x72727272;
    y[1] = 0x73737373;
    y[2] = 0x74747474;
    y[3] = 0x75757575;
    y[4] = 0x76767676;
    y[5] = 0x77777777;
    y[6] = 0x78787878;
    y[7] = 0x79797979;
    y[8] = 0x7a7a7a7a;
    y[9] = 0x31313131;
    y[10] = 0x32323232;
    y[11] = 0x33333333;
    y[12] = 0x34343434;
    y[13] = 0x35353535;
    sha256_update (&shactx3, y, 56);
    printf("UPDATE 2 FINISH\n");
    printf("**************************************************************************\n");
    sha256_final (&shactx3);
    printf("Classic final    : %08x\n", shactx3.h[0]);
    */

    /*
    u32x w0[4] = { 0 };
    u32x w1[4] = { 0 };
    u32x w2[4] = { 0 };
    u32x w3[4] = { 0 };

    w0[0] = 0x72727272;
    w0[1] = 0x73737373;
    w0[2] = 0x74747474;
    w0[3] = 0x75757575;
    w1[0] = 0x76767676;
    w1[1] = 0x77777777;
    w1[2] = 0x78787878;
    w1[3] = 0x79797979;
    w2[0] = 0x7a7a7a7a;
    w2[1] = 0x31313131;
    w2[2] = 0x32323232;
    w2[3] = 0x33333333;
    w3[0] = 0x34343434;
    w3[1] = 0x35353535;

    switch_buffer_by_offset_be_S (w0, w1, w2, w3, 3);
  for (int t = 0; t < 4; t++) {
    printf("    w0[%i]     : %08x\n", t, w0[t]);
  }
  for (int t = 0; t < 4; t++) {
    printf("    w1[%i]     : %08x\n", t, w1[t]);
  }
  for (int t = 0; t < 4; t++) {
    printf("    w2[%i]     : %08x\n", t, w2[t]);
  }
  for (int t = 0; t < 4; t++) {
    printf("    w3[%i]     : %08x\n", t, w3[t]);
  }


    shactx3.w0[0] |= w0[0];
    shactx3.w0[1] |= w0[1];
    shactx3.w0[2] |= w0[2];
    shactx3.w0[3] |= w0[3];
    shactx3.w1[0] |= w1[0];
    shactx3.w1[1] |= w1[1];
    shactx3.w1[2] |= w1[2];
    shactx3.w1[3] |= w1[3];
    shactx3.w2[0] |= w2[0];
    shactx3.w2[1] |= w2[1];
    shactx3.w2[2] |= w2[2];
    shactx3.w2[3] |= w2[3];
    shactx3.w3[0] |= w3[0];
    shactx3.w3[1] |= w3[1];
    shactx3.w3[2] |= w3[2];
    shactx3.w3[3] |= w3[3];
    append_0x80_4x4_S (shactx3.w0, shactx3.w1, shactx3.w2, shactx3.w3, 56);

  for (int t = 0; t < 4; t++) {
    printf("    shactx3.w0[%i]     : %08x\n", t, shactx3.w0[t]);
  }
  for (int t = 0; t < 4; t++) {
    printf("    shactx3.w1[%i]     : %08x\n", t, shactx3.w1[t]);
  }
  for (int t = 0; t < 4; t++) {
    printf("    shactx3.w2[%i]     : %08x\n", t, shactx3.w2[t]);
  }
  for (int t = 0; t < 4; t++) {
    printf("    shactx3.w3[%i]     : %08x\n", t, shactx3.w3[t]);
  }



    u32 a = shactx3.h[0];
    u32 b = shactx3.h[1];
    u32 c = shactx3.h[2];
    u32 d = shactx3.h[3];
    u32 e = shactx3.h[4];
    u32 f = shactx3.h[5];
    u32 g = shactx3.h[6];
    u32 h = shactx3.h[7];

    u32 w0_t = shactx3.w0[0];
    u32 w1_t = shactx3.w0[1];
    u32 w2_t = shactx3.w0[2];
    u32 w3_t = shactx3.w0[3];
    u32 w4_t = shactx3.w1[0];
    u32 w5_t = shactx3.w1[1];
    u32 w6_t = shactx3.w1[2];
    u32 w7_t = shactx3.w1[3];
    u32 w8_t = shactx3.w2[0];
    u32 w9_t = shactx3.w2[1];
    u32 wa_t = shactx3.w2[2];
    u32 wb_t = shactx3.w2[3];
    u32 wc_t = shactx3.w3[0];
    u32 wd_t = shactx3.w3[1];
    u32 we_t = shactx3.w3[2];
    u32 wf_t = shactx3.w3[3];


    SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w0_t, SHA256C00);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w1_t, SHA256C01);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, w2_t, SHA256C02);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, w3_t, SHA256C03);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, w4_t, SHA256C04);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, w5_t, SHA256C05);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, w6_t, SHA256C06);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, w7_t, SHA256C07);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w8_t, SHA256C08);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w9_t, SHA256C09);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, wa_t, SHA256C0a);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, wb_t, SHA256C0b);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, wc_t, SHA256C0c);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, wd_t, SHA256C0d);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, we_t, SHA256C0e);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, wf_t, SHA256C0f);
    ROUND_EXPAND_S()

    SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w0_t, SHA256C10);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w1_t, SHA256C11);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, w2_t, SHA256C12);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, w3_t, SHA256C13);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, w4_t, SHA256C14);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, w5_t, SHA256C15);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, w6_t, SHA256C16);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, w7_t, SHA256C17);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w8_t, SHA256C18);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w9_t, SHA256C19);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, wa_t, SHA256C1a);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, wb_t, SHA256C1b);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, wc_t, SHA256C1c);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, wd_t, SHA256C1d);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, we_t, SHA256C1e);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, wf_t, SHA256C1f);
    ROUND_EXPAND_S()

    SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w0_t, SHA256C20);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w1_t, SHA256C21);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, w2_t, SHA256C22);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, w3_t, SHA256C23);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, w4_t, SHA256C24);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, w5_t, SHA256C25);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, w6_t, SHA256C26);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, w7_t, SHA256C27);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w8_t, SHA256C28);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w9_t, SHA256C29);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, wa_t, SHA256C2a);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, wb_t, SHA256C2b);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, wc_t, SHA256C2c);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, wd_t, SHA256C2d);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, we_t, SHA256C2e);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, wf_t, SHA256C2f);
    ROUND_EXPAND_S()

    SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w0_t, SHA256C30);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w1_t, SHA256C31);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, w2_t, SHA256C32);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, w3_t, SHA256C33);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, w4_t, SHA256C34);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, w5_t, SHA256C35);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, w6_t, SHA256C36);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, w7_t, SHA256C37);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w8_t, SHA256C38);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w9_t, SHA256C39);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, wa_t, SHA256C3a);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, wb_t, SHA256C3b);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, wc_t, SHA256C3c);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, wd_t, SHA256C3d);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, we_t, SHA256C3e);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, wf_t, SHA256C3f);


    shactx3.h[0] += a;
    shactx3.h[1] += b;
    shactx3.h[2] += c;
    shactx3.h[3] += d;
    shactx3.h[4] += e;
    shactx3.h[5] += f;
    shactx3.h[6] += g;
    shactx3.h[7] += h;

    HERE

    w0_t = 0;
    w1_t = 0;
    w2_t = 0;
    w3_t = 0;
    w4_t = 0;
    w5_t = 0;
    w6_t = 0;
    w7_t = 0;
    w8_t = 0;
    w9_t = 0;
    wa_t = 0;
    wb_t = 0;
    wc_t = 0;
    wd_t = 0;
    we_t = 0;
    wf_t = 0x000003d8;

    a = shactx3.h[0];
    b = shactx3.h[1];
    c = shactx3.h[2];
    d = shactx3.h[3];
    e = shactx3.h[4];
    f = shactx3.h[5];
    g = shactx3.h[6];
    h = shactx3.h[7];

    SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w0_t, SHA256C00);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w1_t, SHA256C01);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, w2_t, SHA256C02);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, w3_t, SHA256C03);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, w4_t, SHA256C04);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, w5_t, SHA256C05);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, w6_t, SHA256C06);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, w7_t, SHA256C07);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w8_t, SHA256C08);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w9_t, SHA256C09);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, wa_t, SHA256C0a);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, wb_t, SHA256C0b);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, wc_t, SHA256C0c);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, wd_t, SHA256C0d);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, we_t, SHA256C0e);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, wf_t, SHA256C0f);
    ROUND_EXPAND_S()

    SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w0_t, SHA256C10);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w1_t, SHA256C11);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, w2_t, SHA256C12);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, w3_t, SHA256C13);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, w4_t, SHA256C14);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, w5_t, SHA256C15);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, w6_t, SHA256C16);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, w7_t, SHA256C17);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w8_t, SHA256C18);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w9_t, SHA256C19);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, wa_t, SHA256C1a);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, wb_t, SHA256C1b);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, wc_t, SHA256C1c);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, wd_t, SHA256C1d);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, we_t, SHA256C1e);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, wf_t, SHA256C1f);
    ROUND_EXPAND_S()

    SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w0_t, SHA256C20);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w1_t, SHA256C21);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, w2_t, SHA256C22);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, w3_t, SHA256C23);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, w4_t, SHA256C24);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, w5_t, SHA256C25);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, w6_t, SHA256C26);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, w7_t, SHA256C27);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w8_t, SHA256C28);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w9_t, SHA256C29);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, wa_t, SHA256C2a);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, wb_t, SHA256C2b);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, wc_t, SHA256C2c);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, wd_t, SHA256C2d);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, we_t, SHA256C2e);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, wf_t, SHA256C2f);
    ROUND_EXPAND_S()

    SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w0_t, SHA256C30);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w1_t, SHA256C31);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, w2_t, SHA256C32);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, w3_t, SHA256C33);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, w4_t, SHA256C34);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, w5_t, SHA256C35);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, w6_t, SHA256C36);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, w7_t, SHA256C37);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w8_t, SHA256C38);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w9_t, SHA256C39);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, wa_t, SHA256C3a);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, wb_t, SHA256C3b);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, wc_t, SHA256C3c);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, wd_t, SHA256C3d);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, we_t, SHA256C3e);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, wf_t, SHA256C3f);


    shactx3.h[0] += a;
    shactx3.h[1] += b;
    shactx3.h[2] += c;
    shactx3.h[3] += d;
    shactx3.h[4] += e;
    shactx3.h[5] += f;
    shactx3.h[6] += g;
    shactx3.h[7] += h;

    printf("RES[0]: %08x\n", shactx3.h[0]);
    printf("RES[7]: %08x\n", shactx3.h[7]);



  for (int t = 0; t < 4; t++) {
    printf("    shactx3.w0[%i]     : %08x\n", t, shactx3.w0[t]);
  }
  for (int t = 0; t < 4; t++) {
    printf("    shactx3.w1[%i]     : %08x\n", t, shactx3.w1[t]);
  }
  for (int t = 0; t < 4; t++) {
    printf("    shactx3.w2[%i]     : %08x\n", t, shactx3.w2[t]);
  }
  for (int t = 0; t < 4; t++) {
    printf("    shactx3.w3[%i]     : %08x\n", t, shactx3.w3[t]);
  }
  */













    /*
    u32x x[64] = { 0 };
    x[0] = 0x78787800;
    u32x y[64] = { 0 };
    y[0] = 0x7a616161;
    //x[0] = 0x7a616161;
    sha256_update (&shactx3, x, 3);
    sha256_update (&shactx3, y, 4);
    printf("Classic update   : %08x\n", shactx3.h[0]);
    sha256_final (&shactx3);
    printf("Classic final    : %08x\n", shactx3.h[0]);
    */

    /*
    u32x a = SHA256M_A;
    u32x b = SHA256M_B;
    u32x c = SHA256M_C;
    u32x d = SHA256M_D;
    u32x e = SHA256M_E;
    u32x f = SHA256M_F;
    u32x g = SHA256M_G;
    u32x h = SHA256M_H;


    u32x w0_t = 0x7a616161U;
    u32x w1_t = 0x7a616161U;
    u32x w2_t = 0x7a616161U;
    u32x w3_t = 0x7a616161U;
    u32x w4_t = 0x7a616161U;
    u32x w5_t = 0x7a616161U;
    u32x w6_t = 0x7a616161U;
    u32x w7_t = 0x7a616161U;
    u32x w8_t = 0x7a616161U;
    u32x w9_t = 0x7a616161U;
    u32x wa_t = 0x7a616161U;
    u32x wb_t = 0x7a616161U;
    u32x wc_t = 0x7a616161U;
    u32x wd_t = 0x7a616161U;
    u32x we_t = 0x7a616161U;
    u32x wf_t = 0x7a616161U;

    SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w0_t, SHA256C00);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w1_t, SHA256C01);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, w2_t, SHA256C02);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, w3_t, SHA256C03);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, w4_t, SHA256C04);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, w5_t, SHA256C05);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, w6_t, SHA256C06);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, w7_t, SHA256C07);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w8_t, SHA256C08);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w9_t, SHA256C09);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, wa_t, SHA256C0a);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, wb_t, SHA256C0b);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, wc_t, SHA256C0c);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, wd_t, SHA256C0d);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, we_t, SHA256C0e);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, wf_t, SHA256C0f);
    printf("Optimized update2: %08x\n", a);

    SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w0_t, SHA256C10);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w1_t, SHA256C11);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, w2_t, SHA256C12);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, w3_t, SHA256C13);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, w4_t, SHA256C14);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, w5_t, SHA256C15);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, w6_t, SHA256C16);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, w7_t, SHA256C17);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w8_t, SHA256C18);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w9_t, SHA256C19);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, wa_t, SHA256C1a);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, wb_t, SHA256C1b);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, wc_t, SHA256C1c);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, wd_t, SHA256C1d);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, we_t, SHA256C1e);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, wf_t, SHA256C1f);
    printf("Optimized update3: %08x\n", a);

    SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w0_t, SHA256C20);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w1_t, SHA256C21);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, w2_t, SHA256C22);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, w3_t, SHA256C23);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, w4_t, SHA256C24);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, w5_t, SHA256C25);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, w6_t, SHA256C26);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, w7_t, SHA256C27);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w8_t, SHA256C28);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w9_t, SHA256C29);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, wa_t, SHA256C2a);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, wb_t, SHA256C2b);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, wc_t, SHA256C2c);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, wd_t, SHA256C2d);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, we_t, SHA256C2e);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, wf_t, SHA256C2f);
    printf("Optimized update4: %08x\n", a);

    SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w0_t, SHA256C30);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w1_t, SHA256C31);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, w2_t, SHA256C32);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, w3_t, SHA256C33);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, w4_t, SHA256C34);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, w5_t, SHA256C35);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, w6_t, SHA256C36);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, w7_t, SHA256C37);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w8_t, SHA256C38);
    printf("Optimized update5: %08x\n", a);

    SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w9_t, SHA256C39);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, wa_t, SHA256C3a);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, wb_t, SHA256C3b);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, wc_t, SHA256C3c);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, wd_t, SHA256C3d);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, we_t, SHA256C3e);
    SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, wf_t, SHA256C3f);
    printf("Optimized update6: %08x\n", a);
    */


    /*
    w0_t = SHA256_EXPAND (we_t, w9_t, w1_t, w0_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w0_t, SHA256C10);
    w1_t = SHA256_EXPAND (wf_t, wa_t, w2_t, w1_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w1_t, SHA256C11);
    w2_t = SHA256_EXPAND (w0_t, wb_t, w3_t, w2_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, w2_t, SHA256C12);
    w3_t = SHA256_EXPAND (w1_t, wc_t, w4_t, w3_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, w3_t, SHA256C13);
    w4_t = SHA256_EXPAND (w2_t, wd_t, w5_t, w4_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, w4_t, SHA256C14);
    w5_t = SHA256_EXPAND (w3_t, we_t, w6_t, w5_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, w5_t, SHA256C15);
    w6_t = SHA256_EXPAND (w4_t, wf_t, w7_t, w6_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, w6_t, SHA256C16);
    w7_t = SHA256_EXPAND (w5_t, w0_t, w8_t, w7_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, w7_t, SHA256C17);
    w8_t = SHA256_EXPAND (w6_t, w1_t, w9_t, w8_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w8_t, SHA256C18);
    w9_t = SHA256_EXPAND (w7_t, w2_t, wa_t, w9_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w9_t, SHA256C19);
    wa_t = SHA256_EXPAND (w8_t, w3_t, wb_t, wa_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, wa_t, SHA256C1a);
    wb_t = SHA256_EXPAND (w9_t, w4_t, wc_t, wb_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, wb_t, SHA256C1b);
    wc_t = SHA256_EXPAND (wa_t, w5_t, wd_t, wc_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, wc_t, SHA256C1c);
    wd_t = SHA256_EXPAND (wb_t, w6_t, we_t, wd_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, wd_t, SHA256C1d);
    we_t = SHA256_EXPAND (wc_t, w7_t, wf_t, we_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, we_t, SHA256C1e);
    wf_t = SHA256_EXPAND (wd_t, w8_t, w0_t, wf_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, wf_t, SHA256C1f);
    printf("Optimized update3: %08x\n", a);

    w0_t = SHA256_EXPAND (we_t, w9_t, w1_t, w0_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w0_t, SHA256C20);
    w1_t = SHA256_EXPAND (wf_t, wa_t, w2_t, w1_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w1_t, SHA256C21);
    w2_t = SHA256_EXPAND (w0_t, wb_t, w3_t, w2_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, w2_t, SHA256C22);
    w3_t = SHA256_EXPAND (w1_t, wc_t, w4_t, w3_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, w3_t, SHA256C23);
    w4_t = SHA256_EXPAND (w2_t, wd_t, w5_t, w4_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, w4_t, SHA256C24);
    w5_t = SHA256_EXPAND (w3_t, we_t, w6_t, w5_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, w5_t, SHA256C25);
    w6_t = SHA256_EXPAND (w4_t, wf_t, w7_t, w6_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, w6_t, SHA256C26);
    w7_t = SHA256_EXPAND (w5_t, w0_t, w8_t, w7_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, w7_t, SHA256C27);
    w8_t = SHA256_EXPAND (w6_t, w1_t, w9_t, w8_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w8_t, SHA256C28);
    w9_t = SHA256_EXPAND (w7_t, w2_t, wa_t, w9_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w9_t, SHA256C29);
    wa_t = SHA256_EXPAND (w8_t, w3_t, wb_t, wa_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, wa_t, SHA256C2a);
    wb_t = SHA256_EXPAND (w9_t, w4_t, wc_t, wb_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, wb_t, SHA256C2b);
    wc_t = SHA256_EXPAND (wa_t, w5_t, wd_t, wc_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, wc_t, SHA256C2c);
    wd_t = SHA256_EXPAND (wb_t, w6_t, we_t, wd_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, wd_t, SHA256C2d);
    we_t = SHA256_EXPAND (wc_t, w7_t, wf_t, we_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, we_t, SHA256C2e);
    wf_t = SHA256_EXPAND (wd_t, w8_t, w0_t, wf_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, wf_t, SHA256C2f);
    printf("Optimized update4: %08x\n", a);

    w0_t = SHA256_EXPAND (we_t, w9_t, w1_t, w0_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w0_t, SHA256C30);
    w1_t = SHA256_EXPAND (wf_t, wa_t, w2_t, w1_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w1_t, SHA256C31);
    w2_t = SHA256_EXPAND (w0_t, wb_t, w3_t, w2_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, w2_t, SHA256C32);
    w3_t = SHA256_EXPAND (w1_t, wc_t, w4_t, w3_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, w3_t, SHA256C33);
    w4_t = SHA256_EXPAND (w2_t, wd_t, w5_t, w4_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, w4_t, SHA256C34);
    w5_t = SHA256_EXPAND (w3_t, we_t, w6_t, w5_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, w5_t, SHA256C35);
    w6_t = SHA256_EXPAND (w4_t, wf_t, w7_t, w6_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, w6_t, SHA256C36);
    w7_t = SHA256_EXPAND (w5_t, w0_t, w8_t, w7_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, w7_t, SHA256C37);
    w8_t = SHA256_EXPAND (w6_t, w1_t, w9_t, w8_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w8_t, SHA256C38);
    printf("Optimized update5: %08x\n", a);

    w9_t = SHA256_EXPAND (w7_t, w2_t, wa_t, w9_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w9_t, SHA256C39);
    wa_t = SHA256_EXPAND (w8_t, w3_t, wb_t, wa_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, wa_t, SHA256C3a);
    wb_t = SHA256_EXPAND (w9_t, w4_t, wc_t, wb_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, wb_t, SHA256C3b);
    wc_t = SHA256_EXPAND (wa_t, w5_t, wd_t, wc_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, wc_t, SHA256C3c);
    wd_t = SHA256_EXPAND (wb_t, w6_t, we_t, wd_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, wd_t, SHA256C3d);
    we_t = SHA256_EXPAND (wc_t, w7_t, wf_t, we_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, we_t, SHA256C3e);
    wf_t = SHA256_EXPAND (wd_t, w8_t, w0_t, wf_t); SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, wf_t, SHA256C3f);
    printf("Optimized update6: %08x\n", a);
    */




}
