u32 bytealign (const u32 a, const u32 b, const int c)
{
  u32 r = 0;

  const int cm = c & 3;

       if (cm == 0) { r = b;                     }
  else if (cm == 1) { r = (a << 24) | (b >>  8); }
  else if (cm == 2) { r = (a << 16) | (b >> 16); }
  else if (cm == 3) { r = (a <<  8) | (b >> 24); }

  return r;
}

void set_mark (u32 *v, const u32 offset)
{
  const u32 c = (offset & 15) / 4;
  const u32 r = 0xff << ((offset & 3) * 8);

  v[0] = (c == 0) ? r : 0;
  v[1] = (c == 1) ? r : 0;
  v[2] = (c == 2) ? r : 0;
  v[3] = (c == 3) ? r : 0;
}

void append_helper (u32 *r, const u32 v, const u32 *m)
{
  r[0] |= v & m[0];
  r[1] |= v & m[1];
  r[2] |= v & m[2];
  r[3] |= v & m[3];
}

void append_0x80 (u32 *w0, u32 *w1, u32 *w2, u32 *w3, const u32 offset)
{
  u32 v[4];

  set_mark (v, offset);

  const u32 offset16 = offset / 16;

  append_helper (w0, ((offset16 == 0) ? 0x80808080 : 0), v);
  append_helper (w1, ((offset16 == 1) ? 0x80808080 : 0), v);
  append_helper (w2, ((offset16 == 2) ? 0x80808080 : 0), v);
  append_helper (w3, ((offset16 == 3) ? 0x80808080 : 0), v);
}

u32x rotl32 (const u32x a, const int n)
{
  return ((a << n) | ((a >> (32 - n))));
}

u32x rotr32 (const u32x a, const int n)
{
  return ((a >> n) | ((a << (32 - n))));
}

u32 rotl32_S (const u32 a, const int n)
{
  return ((a << n) | ((a >> (32 - n))));
}

u32 rotr32_S (const u32 a, const int n)
{
  return ((a >> n) | ((a << (32 - n))));
}
