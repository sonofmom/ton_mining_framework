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

    u32x check_index;
    for (check_index = 0; check_index < 8; check_index++) {
        if (data_check[check_index] != 0x00000000) {
            break;
        }
    }

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

    /**
    * Initial CTX Processing
    * We will use comfy interface here since it is only done once.
    */
    sha256_ctx_t ctx;
    sha256_init (&ctx);
    sha256_update_global (&ctx, data_head, HEAD_SIZE_BYTES);

    u32x iterations_counter, found;
    for (iterations_counter = 0; iterations_counter < iterations_max; iterations_counter++) {
        if (abort[0]) {
            break;
        }

        found = 0;

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
        append_0x80_4x4_S (t0, t1, t2, t3, 56);

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
        digest[3] += d;

        SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, wd_t, SHA256C3d);
        digest[2] += c;
        if (check_index < 2 || digest[2] < data_check[2]) {
            SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, we_t, SHA256C3e);
            digest[1] += b;
            if (check_index < 1 || digest[1] < data_check[1] || check_index == 2 && digest[1] == 0x00000000) {
                SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, wf_t, SHA256C3f);
                digest[0] += a;
                if (check_index == 0 && digest[0] < data_check[0] || digest[0] == 0x00000000) {
                    found = 1;
                }
            }
        }


        /**
        * Attention, check below will NOT work when complexity drops below second
        * word (more then 15 zeroes)
        */
        //if (
        //    (digest[0] == 0 && data_check[0] == 0 && digest[1] < data_check[1])
        //    || digest[0] < data_check[0]
        //    ) {
        if (found == 1) {
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
}
