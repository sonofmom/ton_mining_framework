#include "sha256b.h"

__constant u32a k_sha256[64] =
{
  SHA256C00, SHA256C01, SHA256C02, SHA256C03,
  SHA256C04, SHA256C05, SHA256C06, SHA256C07,
  SHA256C08, SHA256C09, SHA256C0a, SHA256C0b,
  SHA256C0c, SHA256C0d, SHA256C0e, SHA256C0f,
  SHA256C10, SHA256C11, SHA256C12, SHA256C13,
  SHA256C14, SHA256C15, SHA256C16, SHA256C17,
  SHA256C18, SHA256C19, SHA256C1a, SHA256C1b,
  SHA256C1c, SHA256C1d, SHA256C1e, SHA256C1f,
  SHA256C20, SHA256C21, SHA256C22, SHA256C23,
  SHA256C24, SHA256C25, SHA256C26, SHA256C27,
  SHA256C28, SHA256C29, SHA256C2a, SHA256C2b,
  SHA256C2c, SHA256C2d, SHA256C2e, SHA256C2f,
  SHA256C30, SHA256C31, SHA256C32, SHA256C33,
  SHA256C34, SHA256C35, SHA256C36, SHA256C37,
  SHA256C38, SHA256C39, SHA256C3a, SHA256C3b,
  SHA256C3c, SHA256C3d, SHA256C3e, SHA256C3f,
};


// bit rotates
//
// For _CPU_OPENCL_EMU_H we dont need to care about vector functions
// The VECT_SIZE is guaranteed to be set to 1 from cpu_opencl_emu.h

u32x hc_rotl32 (const u32x a, const int n)
{
  return ((a << n) | (a >> (32 - n)));
}

u32x hc_rotr32 (const u32x a, const int n)
{
  return ((a >> n) | (a << (32 - n)));
}

u32 hc_rotl32_S (const u32 a, const int n)
{
  return ((a << n) | (a >> (32 - n)));
}

u32 hc_rotr32_S (const u32 a, const int n)
{
  return ((a >> n) | (a << (32 - n)));
}


// important notes on this:
// input buf unused bytes needs to be set to zero
// input buf needs to be in algorithm native byte order (md5 = LE, sha256 = BE, etc)
// input buf needs to be 64 byte aligned when using sha256_update()

void sha256_transform (const u32 *w0, const u32 *w1, const u32 *w2, const u32 *w3, u32 *digest)
{
  u32 a = digest[0];
  u32 b = digest[1];
  u32 c = digest[2];
  u32 d = digest[3];
  u32 e = digest[4];
  u32 f = digest[5];
  u32 g = digest[6];
  u32 h = digest[7];

  u32 w0_t = w0[0];
  u32 w1_t = w0[1];
  u32 w2_t = w0[2];
  u32 w3_t = w0[3];
  u32 w4_t = w1[0];
  u32 w5_t = w1[1];
  u32 w6_t = w1[2];
  u32 w7_t = w1[3];
  u32 w8_t = w2[0];
  u32 w9_t = w2[1];
  u32 wa_t = w2[2];
  u32 wb_t = w2[3];
  u32 wc_t = w3[0];
  u32 wd_t = w3[1];
  u32 we_t = w3[2];
  u32 wf_t = w3[3];

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

  #define ROUND_STEP_S(i)                                                                   \
  {                                                                                         \
    SHA256_STEP_S (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w0_t, k_sha256[i +  0]); \
    SHA256_STEP_S (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w1_t, k_sha256[i +  1]); \
    SHA256_STEP_S (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, w2_t, k_sha256[i +  2]); \
    SHA256_STEP_S (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, w3_t, k_sha256[i +  3]); \
    SHA256_STEP_S (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, w4_t, k_sha256[i +  4]); \
    SHA256_STEP_S (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, w5_t, k_sha256[i +  5]); \
    SHA256_STEP_S (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, w6_t, k_sha256[i +  6]); \
    SHA256_STEP_S (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, w7_t, k_sha256[i +  7]); \
    SHA256_STEP_S (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w8_t, k_sha256[i +  8]); \
    SHA256_STEP_S (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w9_t, k_sha256[i +  9]); \
    SHA256_STEP_S (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, wa_t, k_sha256[i + 10]); \
    SHA256_STEP_S (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, wb_t, k_sha256[i + 11]); \
    SHA256_STEP_S (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, wc_t, k_sha256[i + 12]); \
    SHA256_STEP_S (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, wd_t, k_sha256[i + 13]); \
    SHA256_STEP_S (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, we_t, k_sha256[i + 14]); \
    SHA256_STEP_S (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, wf_t, k_sha256[i + 15]); \
  }

  ROUND_STEP_S (0);

  #ifdef _unroll
  #pragma unroll
  #endif
  for (int i = 16; i < 64; i += 16)
  {
    ROUND_EXPAND_S (); ROUND_STEP_S (i);
  }

  #undef ROUND_EXPAND_S
  #undef ROUND_STEP_S

  digest[0] += a;
  digest[1] += b;
  digest[2] += c;
  digest[3] += d;
  digest[4] += e;
  digest[5] += f;
  digest[6] += g;
  digest[7] += h;
}

void sha256_init (sha256_ctx_t *ctx)
{
  ctx->h[0] = SHA256M_A;
  ctx->h[1] = SHA256M_B;
  ctx->h[2] = SHA256M_C;
  ctx->h[3] = SHA256M_D;
  ctx->h[4] = SHA256M_E;
  ctx->h[5] = SHA256M_F;
  ctx->h[6] = SHA256M_G;
  ctx->h[7] = SHA256M_H;

  ctx->w0[0] = 0;
  ctx->w0[1] = 0;
  ctx->w0[2] = 0;
  ctx->w0[3] = 0;
  ctx->w1[0] = 0;
  ctx->w1[1] = 0;
  ctx->w1[2] = 0;
  ctx->w1[3] = 0;
  ctx->w2[0] = 0;
  ctx->w2[1] = 0;
  ctx->w2[2] = 0;
  ctx->w2[3] = 0;
  ctx->w3[0] = 0;
  ctx->w3[1] = 0;
  ctx->w3[2] = 0;
  ctx->w3[3] = 0;

  ctx->len = 0;
}

void sha256_update_64 (sha256_ctx_t *ctx, u32 *w0, u32 *w1, u32 *w2, u32 *w3, const int len)
{
  if (len == 0) return;

  const int pos = ctx->len & 63;

  ctx->len += len;

  if (pos == 0)
  {
    ctx->w0[0] = w0[0];
    ctx->w0[1] = w0[1];
    ctx->w0[2] = w0[2];
    ctx->w0[3] = w0[3];
    ctx->w1[0] = w1[0];
    ctx->w1[1] = w1[1];
    ctx->w1[2] = w1[2];
    ctx->w1[3] = w1[3];
    ctx->w2[0] = w2[0];
    ctx->w2[1] = w2[1];
    ctx->w2[2] = w2[2];
    ctx->w2[3] = w2[3];
    ctx->w3[0] = w3[0];
    ctx->w3[1] = w3[1];
    ctx->w3[2] = w3[2];
    ctx->w3[3] = w3[3];

    if (len == 64)
    {
      sha256_transform (ctx->w0, ctx->w1, ctx->w2, ctx->w3, ctx->h);

      ctx->w0[0] = 0;
      ctx->w0[1] = 0;
      ctx->w0[2] = 0;
      ctx->w0[3] = 0;
      ctx->w1[0] = 0;
      ctx->w1[1] = 0;
      ctx->w1[2] = 0;
      ctx->w1[3] = 0;
      ctx->w2[0] = 0;
      ctx->w2[1] = 0;
      ctx->w2[2] = 0;
      ctx->w2[3] = 0;
      ctx->w3[0] = 0;
      ctx->w3[1] = 0;
      ctx->w3[2] = 0;
      ctx->w3[3] = 0;
    }
  }
  else
  {
    if ((pos + len) < 64)
    {
      switch_buffer_by_offset_be_S (w0, w1, w2, w3, pos);

      ctx->w0[0] |= w0[0];
      ctx->w0[1] |= w0[1];
      ctx->w0[2] |= w0[2];
      ctx->w0[3] |= w0[3];
      ctx->w1[0] |= w1[0];
      ctx->w1[1] |= w1[1];
      ctx->w1[2] |= w1[2];
      ctx->w1[3] |= w1[3];
      ctx->w2[0] |= w2[0];
      ctx->w2[1] |= w2[1];
      ctx->w2[2] |= w2[2];
      ctx->w2[3] |= w2[3];
      ctx->w3[0] |= w3[0];
      ctx->w3[1] |= w3[1];
      ctx->w3[2] |= w3[2];
      ctx->w3[3] |= w3[3];
    }
    else
    {
      u32 c0[4] = { 0 };
      u32 c1[4] = { 0 };
      u32 c2[4] = { 0 };
      u32 c3[4] = { 0 };

      switch_buffer_by_offset_carry_be_S (w0, w1, w2, w3, c0, c1, c2, c3, pos);

      ctx->w0[0] |= w0[0];
      ctx->w0[1] |= w0[1];
      ctx->w0[2] |= w0[2];
      ctx->w0[3] |= w0[3];
      ctx->w1[0] |= w1[0];
      ctx->w1[1] |= w1[1];
      ctx->w1[2] |= w1[2];
      ctx->w1[3] |= w1[3];
      ctx->w2[0] |= w2[0];
      ctx->w2[1] |= w2[1];
      ctx->w2[2] |= w2[2];
      ctx->w2[3] |= w2[3];
      ctx->w3[0] |= w3[0];
      ctx->w3[1] |= w3[1];
      ctx->w3[2] |= w3[2];
      ctx->w3[3] |= w3[3];

      sha256_transform (ctx->w0, ctx->w1, ctx->w2, ctx->w3, ctx->h);

      ctx->w0[0] = c0[0];
      ctx->w0[1] = c0[1];
      ctx->w0[2] = c0[2];
      ctx->w0[3] = c0[3];
      ctx->w1[0] = c1[0];
      ctx->w1[1] = c1[1];
      ctx->w1[2] = c1[2];
      ctx->w1[3] = c1[3];
      ctx->w2[0] = c2[0];
      ctx->w2[1] = c2[1];
      ctx->w2[2] = c2[2];
      ctx->w2[3] = c2[3];
      ctx->w3[0] = c3[0];
      ctx->w3[1] = c3[1];
      ctx->w3[2] = c3[2];
      ctx->w3[3] = c3[3];
    }
  }
}

void sha256_update (sha256_ctx_t *ctx, const u32 *w, const int len)
{
  u32 w0[4];
  u32 w1[4];
  u32 w2[4];
  u32 w3[4];

  int pos1;
  int pos4;

  for (pos1 = 0, pos4 = 0; pos1 < len - 64; pos1 += 64, pos4 += 16)
  {
    w0[0] = w[pos4 +  0];
    w0[1] = w[pos4 +  1];
    w0[2] = w[pos4 +  2];
    w0[3] = w[pos4 +  3];
    w1[0] = w[pos4 +  4];
    w1[1] = w[pos4 +  5];
    w1[2] = w[pos4 +  6];
    w1[3] = w[pos4 +  7];
    w2[0] = w[pos4 +  8];
    w2[1] = w[pos4 +  9];
    w2[2] = w[pos4 + 10];
    w2[3] = w[pos4 + 11];
    w3[0] = w[pos4 + 12];
    w3[1] = w[pos4 + 13];
    w3[2] = w[pos4 + 14];
    w3[3] = w[pos4 + 15];

    sha256_update_64 (ctx, w0, w1, w2, w3, 64);
  }

  w0[0] = w[pos4 +  0];
  w0[1] = w[pos4 +  1];
  w0[2] = w[pos4 +  2];
  w0[3] = w[pos4 +  3];
  w1[0] = w[pos4 +  4];
  w1[1] = w[pos4 +  5];
  w1[2] = w[pos4 +  6];
  w1[3] = w[pos4 +  7];
  w2[0] = w[pos4 +  8];
  w2[1] = w[pos4 +  9];
  w2[2] = w[pos4 + 10];
  w2[3] = w[pos4 + 11];
  w3[0] = w[pos4 + 12];
  w3[1] = w[pos4 + 13];
  w3[2] = w[pos4 + 14];
  w3[3] = w[pos4 + 15];

  sha256_update_64 (ctx, w0, w1, w2, w3, len - pos1);
}
