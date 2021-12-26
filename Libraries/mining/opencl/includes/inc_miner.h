typedef ulong   ullong;
typedef ulong2  ullong2;
typedef ulong4  ullong4;
typedef ulong8  ullong8;
typedef ulong16 ullong16;
typedef uchar  u8;
typedef ushort u16;
typedef uint   u32;
typedef ullong u64;
typedef u8   u8x;
typedef u16  u16x;
typedef u32  u32x;
typedef u64  u64x;

u32  bytealign (const u32  a, const u32  b, const int  c);
void append_0x80 (u32 *w0, u32 *w1, u32 *w2, u32 *w3, const u32 offset);
void append_helper (u32x *r, const u32 v, const u32 *m);
void set_mark (u32 *v, const u32 offset);
u32x rotl32   (const u32x a, const int n);
u32x rotr32   (const u32x a, const int n);
u32  rotl32_S (const u32  a, const int n);
u32  rotr32_S (const u32  a, const int n);

typedef enum sha2_32_constants
{
  // SHA-256 Constants
  SHA256C00=0x428a2f98U,
  SHA256C01=0x71374491U,
  SHA256C02=0xb5c0fbcfU,
  SHA256C03=0xe9b5dba5U,
  SHA256C04=0x3956c25bU,
  SHA256C05=0x59f111f1U,
  SHA256C06=0x923f82a4U,
  SHA256C07=0xab1c5ed5U,
  SHA256C08=0xd807aa98U,
  SHA256C09=0x12835b01U,
  SHA256C0a=0x243185beU,
  SHA256C0b=0x550c7dc3U,
  SHA256C0c=0x72be5d74U,
  SHA256C0d=0x80deb1feU,
  SHA256C0e=0x9bdc06a7U,
  SHA256C0f=0xc19bf174U,
  SHA256C10=0xe49b69c1U,
  SHA256C11=0xefbe4786U,
  SHA256C12=0x0fc19dc6U,
  SHA256C13=0x240ca1ccU,
  SHA256C14=0x2de92c6fU,
  SHA256C15=0x4a7484aaU,
  SHA256C16=0x5cb0a9dcU,
  SHA256C17=0x76f988daU,
  SHA256C18=0x983e5152U,
  SHA256C19=0xa831c66dU,
  SHA256C1a=0xb00327c8U,
  SHA256C1b=0xbf597fc7U,
  SHA256C1c=0xc6e00bf3U,
  SHA256C1d=0xd5a79147U,
  SHA256C1e=0x06ca6351U,
  SHA256C1f=0x14292967U,
  SHA256C20=0x27b70a85U,
  SHA256C21=0x2e1b2138U,
  SHA256C22=0x4d2c6dfcU,
  SHA256C23=0x53380d13U,
  SHA256C24=0x650a7354U,
  SHA256C25=0x766a0abbU,
  SHA256C26=0x81c2c92eU,
  SHA256C27=0x92722c85U,
  SHA256C28=0xa2bfe8a1U,
  SHA256C29=0xa81a664bU,
  SHA256C2a=0xc24b8b70U,
  SHA256C2b=0xc76c51a3U,
  SHA256C2c=0xd192e819U,
  SHA256C2d=0xd6990624U,
  SHA256C2e=0xf40e3585U,
  SHA256C2f=0x106aa070U,
  SHA256C30=0x19a4c116U,
  SHA256C31=0x1e376c08U,
  SHA256C32=0x2748774cU,
  SHA256C33=0x34b0bcb5U,
  SHA256C34=0x391c0cb3U,
  SHA256C35=0x4ed8aa4aU,
  SHA256C36=0x5b9cca4fU,
  SHA256C37=0x682e6ff3U,
  SHA256C38=0x748f82eeU,
  SHA256C39=0x78a5636fU,
  SHA256C3a=0x84c87814U,
  SHA256C3b=0x8cc70208U,
  SHA256C3c=0x90befffaU,
  SHA256C3d=0xa4506cebU,
  SHA256C3e=0xbef9a3f7U,
  SHA256C3f=0xc67178f2U,
} sha2_32_constants_t;

#define SHIFT_RIGHT_32(x,n) ((x) >> (n))

#define SHA256_S0_S(x) (rotl32_S ((x), 25u) ^ rotl32_S ((x), 14u) ^ SHIFT_RIGHT_32 ((x),  3u))
#define SHA256_S1_S(x) (rotl32_S ((x), 15u) ^ rotl32_S ((x), 13u) ^ SHIFT_RIGHT_32 ((x), 10u))
#define SHA256_S2(x) (rotl32 ((x), 30u) ^ rotl32 ((x), 19u) ^ rotl32 ((x), 10u))
#define SHA256_S3(x) (rotl32 ((x), 26u) ^ rotl32 ((x), 21u) ^ rotl32 ((x),  7u))
#define SHA256_F0(x,y,z)  (((x) & (y)) | ((z) & ((x) ^ (y))))
#define SHA256_F1(x,y,z)  ((z) ^ ((x) & ((y) ^ (z))))

#define SHA256_F0o(x,y,z) (SHA256_F0 ((x), (y), (z)))
#define SHA256_F1o(x,y,z) (SHA256_F1 ((x), (y), (z)))

#define SHA256_EXPAND_S(x,y,z,w) (SHA256_S1_S (x) + y + SHA256_S0_S (z) + w)

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

#define SHA256_STEP(F0,F1,a,b,c,d,e,f,g,h,x,K)      \
{                                                   \
  h = h + K + x;                                    \
  h = h + SHA256_S3 (e) + F1 (e,f,g);              \
  d += h;                                           \
  h = h + SHA256_S2 (a) + F0 (a,b,c);              \
}
