#include "inc_vendor.h"
#include "inc_types.h"
#include "inc_platform.cl"
#include "inc_common.cl"
#include "inc_simd.cl"
#include "inc_hash_sha256.cl"


#ifndef uint32_t
#define uint32_t unsigned int
#endif


uint rotr(uint x, int n) {
    if (n < 32) return (x >> n) | (x << (32 - n));
    return x;
}

uint ch(uint x, uint y, uint z) {
    return (x & y) ^ (~x & z);
}

uint maj(uint x, uint y, uint z) {
    return (x & y) ^ (x & z) ^ (y & z);
}

uint sigma0(uint x) {
    return rotr(x, 2) ^ rotr(x, 13) ^ rotr(x, 22);
}

uint sigma1(uint x) {
    return rotr(x, 6) ^ rotr(x, 11) ^ rotr(x, 25);
}

uint gamma0(uint x) {
    return rotr(x, 7) ^ rotr(x, 18) ^ (x >> 3);
}

uint gamma1(uint x) {
    return rotr(x, 17) ^ rotr(x, 19) ^ (x >> 10);
}

void sha256_initZ(uint *digest) {
    digest[0] = 0x6a09e667;
    digest[1] = 0xbb67ae85;
    digest[2] = 0x3c6ef372;
    digest[3] = 0xa54ff53a;
    digest[4] = 0x510e527f;
    digest[5] = 0x9b05688c;
    digest[6] = 0x1f83d9ab;
    digest[7] = 0x5be0cd19;
}

void sha256_process(char *raw_data, int data_size, uint *digest){
    int t, msg_pad;
    int stop, mmod;
    int current_pad;
    uint i, item, total, size;
    size = data_size;
    uint W[80], temp, A,B,C,D,E,F,G,H,T1,T2;

    /*
    printf("     PROC  String PTR: %p, Digest PRT: %p\n", raw_data, digest);
    printf("     PROC  String PTR: %p, Digest PRT: %p\n", raw_data, digest);
    printf("     PROC  String: '");
    for (int pos = 0; pos < data_size; pos++){
        printf("%c", raw_data[pos]);
    }
    printf("'\n");
    */

    uint K[64]={
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    };

    msg_pad=0;

    total = size%64>=56?2:1 + size/64;

    for(item=0; item<total; item++) {
        A = digest[0];
        B = digest[1];
        C = digest[2];
        D = digest[3];
        E = digest[4];
        F = digest[5];
        G = digest[6];
        H = digest[7];

        #pragma unroll
            for (t = 0; t < 80; t++){
                W[t] = 0x00000000;
            }
            msg_pad=item*64;
            if(size > msg_pad) {
                current_pad = (size-msg_pad)>64?64:(size-msg_pad);
            }
            else
            {
                current_pad =-1;
            }

            /* printf("current_pad: %d\n",current_pad); */
            if(current_pad>0) {
                i=current_pad;
                stop =  i/4;
                /* printf("i:%d, stop: %d msg_pad:%d\n",i,stop, msg_pad); */
                for (t = 0 ; t < stop ; t++){
                    W[t] = ((uchar)  raw_data[msg_pad + t * 4]) << 24;
                    W[t] |= ((uchar) raw_data[msg_pad + t * 4 + 1]) << 16;
                    W[t] |= ((uchar) raw_data[msg_pad + t * 4 + 2]) << 8;
                    W[t] |= (uchar)  raw_data[msg_pad + t * 4 + 3];
                    /* printf("W[%u]: %u\n",t,W[t]); */
                }
                mmod = i % 4;
                /* printf("mmod:%d\n",mmod); */
                if ( mmod == 3){
                    /* printf("W[%u]: %u\n",t,W[t]); */
                    W[t] = ((uchar)  raw_data[msg_pad + t * 4]) << 24;
                    W[t] |= ((uchar) raw_data[msg_pad + t * 4 + 1]) << 16;
                    W[t] |= ((uchar) raw_data[msg_pad + t * 4 + 2]) << 8;
                    W[t] |=  ((uchar) 0x80) ;
                    /* printf("W[%u]: %u\n",t,W[t]); */
                } else if (mmod == 2) {
                    W[t] = ((uchar)  raw_data[msg_pad + t * 4]) << 24;
                    W[t] |= ((uchar) raw_data[msg_pad + t * 4 + 1]) << 16;
                    W[t] |=  0x8000 ;
                } else if (mmod == 1) {
                    W[t] = ((uchar)  raw_data[msg_pad + t * 4]) << 24;
                    W[t] |=  0x800000 ;
                } else /*if (mmod == 0)*/ {
                    W[t] =  0x80000000 ;
                }

                if (current_pad<56) {
                    W[15] =  size*8 ;
                }
            } else if(current_pad <0) {
                if( size%64==0) {
                    W[0]=0x80000000;
                }
                W[15]=size*8;
            }

            for (t = 0; t < 64; t++) {
                if (t >= 16) {
                    W[t] = gamma1(W[t - 2]) + W[t - 7] + gamma0(W[t - 15]) + W[t - 16];
                }
                T1 = H + sigma1(E) + ch(E, F, G) + K[t] + W[t];
                T2 = sigma0(A) + maj(A, B, C);
                H = G; G = F; F = E; E = D + T1; D = C; C = B; B = A; A = T1 + T2;
            }

            digest[0] += A;
            digest[1] += B;
            digest[2] += C;
            digest[3] += D;
            digest[4] += E;
            digest[5] += F;
            digest[6] += G;
            digest[7] += H;


            //  for (t = 0; t < 80; t++)
            //    {
            //    printf("W[%d]: %u\n",t,W[t]);
            //    }
    }
}
