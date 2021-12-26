typedef uchar  u8;
typedef ushort u16;
typedef uint   u32;
typedef ulong u64;


typedef u8  u8a;
typedef u16 u16a;
typedef u32 u32a;
typedef u64 u64a;

typedef u8   u8x;
typedef u16  u16x;
typedef u32  u32x;
typedef u64  u64x;

typedef enum sha2_32_constants
{
  // SHA-224 Initial Hash Values
  SHA224M_A=0xc1059ed8U,
  SHA224M_B=0x367cd507U,
  SHA224M_C=0x3070dd17U,
  SHA224M_D=0xf70e5939U,
  SHA224M_E=0xffc00b31U,
  SHA224M_F=0x68581511U,
  SHA224M_G=0x64f98fa7U,
  SHA224M_H=0xbefa4fa4U,

  // SHA-224 Constants
  SHA224C00=0x428a2f98U,
  SHA224C01=0x71374491U,
  SHA224C02=0xb5c0fbcfU,
  SHA224C03=0xe9b5dba5U,
  SHA224C04=0x3956c25bU,
  SHA224C05=0x59f111f1U,
  SHA224C06=0x923f82a4U,
  SHA224C07=0xab1c5ed5U,
  SHA224C08=0xd807aa98U,
  SHA224C09=0x12835b01U,
  SHA224C0a=0x243185beU,
  SHA224C0b=0x550c7dc3U,
  SHA224C0c=0x72be5d74U,
  SHA224C0d=0x80deb1feU,
  SHA224C0e=0x9bdc06a7U,
  SHA224C0f=0xc19bf174U,
  SHA224C10=0xe49b69c1U,
  SHA224C11=0xefbe4786U,
  SHA224C12=0x0fc19dc6U,
  SHA224C13=0x240ca1ccU,
  SHA224C14=0x2de92c6fU,
  SHA224C15=0x4a7484aaU,
  SHA224C16=0x5cb0a9dcU,
  SHA224C17=0x76f988daU,
  SHA224C18=0x983e5152U,
  SHA224C19=0xa831c66dU,
  SHA224C1a=0xb00327c8U,
  SHA224C1b=0xbf597fc7U,
  SHA224C1c=0xc6e00bf3U,
  SHA224C1d=0xd5a79147U,
  SHA224C1e=0x06ca6351U,
  SHA224C1f=0x14292967U,
  SHA224C20=0x27b70a85U,
  SHA224C21=0x2e1b2138U,
  SHA224C22=0x4d2c6dfcU,
  SHA224C23=0x53380d13U,
  SHA224C24=0x650a7354U,
  SHA224C25=0x766a0abbU,
  SHA224C26=0x81c2c92eU,
  SHA224C27=0x92722c85U,
  SHA224C28=0xa2bfe8a1U,
  SHA224C29=0xa81a664bU,
  SHA224C2a=0xc24b8b70U,
  SHA224C2b=0xc76c51a3U,
  SHA224C2c=0xd192e819U,
  SHA224C2d=0xd6990624U,
  SHA224C2e=0xf40e3585U,
  SHA224C2f=0x106aa070U,
  SHA224C30=0x19a4c116U,
  SHA224C31=0x1e376c08U,
  SHA224C32=0x2748774cU,
  SHA224C33=0x34b0bcb5U,
  SHA224C34=0x391c0cb3U,
  SHA224C35=0x4ed8aa4aU,
  SHA224C36=0x5b9cca4fU,
  SHA224C37=0x682e6ff3U,
  SHA224C38=0x748f82eeU,
  SHA224C39=0x78a5636fU,
  SHA224C3a=0x84c87814U,
  SHA224C3b=0x8cc70208U,
  SHA224C3c=0x90befffaU,
  SHA224C3d=0xa4506cebU,
  SHA224C3e=0xbef9a3f7U,
  SHA224C3f=0xc67178f2U,

  // SHA-256 Initial Hash Values
  SHA256M_A=0x6a09e667U,
  SHA256M_B=0xbb67ae85U,
  SHA256M_C=0x3c6ef372U,
  SHA256M_D=0xa54ff53aU,
  SHA256M_E=0x510e527fU,
  SHA256M_F=0x9b05688cU,
  SHA256M_G=0x1f83d9abU,
  SHA256M_H=0x5be0cd19U,

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

#define SHA256_S0_S(x) (hc_rotl32_S ((x), 25u) ^ hc_rotl32_S ((x), 14u) ^ SHIFT_RIGHT_32 ((x),  3u))
#define SHA256_S1_S(x) (hc_rotl32_S ((x), 15u) ^ hc_rotl32_S ((x), 13u) ^ SHIFT_RIGHT_32 ((x), 10u))
#define SHA256_S2_S(x) (hc_rotl32_S ((x), 30u) ^ hc_rotl32_S ((x), 19u) ^ hc_rotl32_S ((x), 10u))
#define SHA256_S3_S(x) (hc_rotl32_S ((x), 26u) ^ hc_rotl32_S ((x), 21u) ^ hc_rotl32_S ((x),  7u))

#define SHA256_S0(x) (hc_rotl32 ((x), 25u) ^ hc_rotl32 ((x), 14u) ^ SHIFT_RIGHT_32 ((x),  3u))
#define SHA256_S1(x) (hc_rotl32 ((x), 15u) ^ hc_rotl32 ((x), 13u) ^ SHIFT_RIGHT_32 ((x), 10u))
#define SHA256_S2(x) (hc_rotl32 ((x), 30u) ^ hc_rotl32 ((x), 19u) ^ hc_rotl32 ((x), 10u))
#define SHA256_S3(x) (hc_rotl32 ((x), 26u) ^ hc_rotl32 ((x), 21u) ^ hc_rotl32 ((x),  7u))

#define SHA256_F0(x,y,z)  (((x) & (y)) | ((z) & ((x) ^ (y))))
#define SHA256_F1(x,y,z)  ((z) ^ ((x) & ((y) ^ (z))))

#define SHA256_F0o(x,y,z) (SHA256_F0 ((x), (y), (z)))
#define SHA256_F1o(x,y,z) (SHA256_F1 ((x), (y), (z)))

#define SHA256_STEP_S(F0,F1,a,b,c,d,e,f,g,h,x,K)  \
{                                                 \
  h = hc_add3_S (h, K, x);                        \
  h = hc_add3_S (h, SHA256_S3_S (e), F1 (e,f,g)); \
  d += h;                                         \
  h = hc_add3_S (h, SHA256_S2_S (a), F0 (a,b,c)); \
}

#define SHA256_EXPAND_S(x,y,z,w) (SHA256_S1_S (x) + y + SHA256_S0_S (z) + w)

#define SHA256_STEP(F0,F1,a,b,c,d,e,f,g,h,x,K)    \
{                                                 \
  h = hc_add3 (h, K, x);                          \
  h = hc_add3 (h, SHA256_S3 (e), F1 (e,f,g));     \
  d += h;                                         \
  h = hc_add3 (h, SHA256_S2 (a), F0 (a,b,c));     \
}

#define SHA256_EXPAND(x,y,z,w) (SHA256_S1 (x) + y + SHA256_S0 (z) + w)

typedef struct sha256_ctx
{
  u32 h[8];

  u32 w0[4];
  u32 w1[4];
  u32 w2[4];
  u32 w3[4];

  int len;

} sha256_ctx_t;
