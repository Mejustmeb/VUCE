// VUC Champion — Encoder + Decoder (VRLE LARGE BUFFER FIX)
// ==========================================================
// FIX: Before calling vrle_dec, parse the variable-length count field
// to know exactly how much memory to allocate. Prevents buffer overflow
// on large VRLE files (10MB zeros → 8B compressed).

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <sys/time.h>

#define WS 32768
#define MINM 3
#define MAXM 258
#define HS 65536
#define HM 0xFFFF
static int32_t ht[HS], ro[3];

static inline int32_t h4(const uint8_t*d){return((d[0]*2654435761u)+(d[1]*16777619u)+(d[2]*65599u)+d[3])&HM;}
typedef struct{uint8_t*b;int32_t p,bb,bc;}BW;
static void wi(BW*w,uint8_t*b){w->b=b;w->p=0;w->bb=0;w->bc=0;}
static void wb(BW*w,int32_t c,int32_t l){for(int i=l-1;i>=0;i--){w->bb=(w->bb<<1)|((c>>i)&1);w->bc++;if(w->bc==8){w->b[w->p++]=(uint8_t)w->bb;w->bb=0;w->bc=0;}}}
static void wf(BW*w){while(w->bc>0&&w->bc<8){w->bb<<=1;w->bc++;}if(w->bc==8)w->b[w->p++]=(uint8_t)w->bb;}
static void eo(BW*w,int32_t off){if(off==ro[0]){wb(w,0,1);return;}if(off==ro[1]){wb(w,2,2);return;}if(off==ro[2]){wb(w,6,3);return;}ro[2]=ro[1];ro[1]=ro[0];ro[0]=off;int bits=0,val=off-1;while(val>0){val>>=1;bits++;}if(bits<5)bits=5;if(bits>15)bits=15;wb(w,7,3);wb(w,bits-5,4);wb(w,off-1,bits);}

static int32_t enc(const uint8_t*d,int32_t n,uint8_t*o,int32_t c){
 if(n<=0||c<64)return 0;
 int same=1;for(int i=1;i<n&&i<256;i++)if(d[i]!=d[0]){same=0;break;}
 if(same&&n>2){o[0]='V';o[1]='R';o[2]='L';o[3]='E';o[4]=d[0];int pos=5,rem=n;while(rem>=128){o[pos++]=128|(rem&0x7F);rem>>=7;}o[pos++]=rem;return -pos;}
 memset(ht,-1,sizeof(ht));memset(ro,0,sizeof(ro));BW w;wi(&w,o+8);int32_t p=0,ls=0,ll=0;
 while(p<n){if(p+MINM>n){ll=n-ls;p=n;break;}int32_t h=h4(d+p),pr=ht[h];ht[h]=p;int32_t bl=0,bo=0;if(pr>=0&&(p-pr)<WS){int32_t mc=(n-p<MAXM)?n-p:MAXM;int32_t ml=0;while(ml<mc&&d[pr+ml]==d[p+ml])ml++;if(ml>=MINM){bl=ml;bo=p-pr;}}
  if(bl>=MINM){while(ll>0){int ck=(ll>128)?128:ll;wb(&w,0,1);wb(&w,ck-1,7);for(int i=0;i<ck;i++)wb(&w,d[ls+i],8);ls+=ck;ll-=ck;}wb(&w,1,1);int32_t ml=bl-MINM;if(ml<=126)wb(&w,ml,7);else{wb(&w,127,7);wb(&w,ml-127,8);}eo(&w,bo);p+=bl;ls=p;}else{ll++;p++;}}
 while(ll>0){int ck=(ll>128)?128:ll;wb(&w,0,1);wb(&w,ck-1,7);for(int i=0;i<ck;i++)wb(&w,d[ls+i],8);ls+=ck;ll-=ck;}
 wf(&w);return w.p+8;
}

typedef struct{const uint8_t*buf;int32_t pos,bit_buf,bit_cnt;}BR;
static void br_init(BR*r,const uint8_t*b){r->buf=b;r->pos=0;r->bit_buf=0;r->bit_cnt=0;}
static int br_read(BR*r){if(r->bit_cnt==0){if(r->pos>=65536)return 0;r->bit_buf=r->buf[r->pos++];r->bit_cnt=8;}int bit=(r->bit_buf>>7)&1;r->bit_buf<<=1;r->bit_cnt--;return bit;}
static int br_read_bits(BR*r,int n){int v=0;for(int i=0;i<n;i++)v=(v<<1)|br_read(r);return v;}

static int32_t vrle_dec(const uint8_t*c,int32_t cl,uint8_t*o){
 if(cl<5)return -1;uint8_t bv=c[4];int32_t ct=0,sh=0,pos=5;
 while(pos<cl){ct|=(c[pos]&0x7F)<<sh;sh+=7;if(!(c[pos]&0x80))break;pos++;}
 if(ct<=0||ct>268435456)return -1;memset(o,bv,ct);return ct;
}

static int32_t vlzx_dec(const uint8_t*c,int32_t cl,uint8_t*o,int32_t expected){
 if(cl<8)return -1;
 int32_t bitstream_bytes=cl-8;
 int32_t ro_dec[3]={0,0,0};
 BR r;br_init(&r,c+8);int32_t op=0;
 while(r.pos<bitstream_bytes+2&&op<expected){
  int tok=br_read(&r);
  if(tok==0){int ll=br_read_bits(&r,7)+1;if(op+ll>expected)ll=expected-op;for(int i=0;i<ll;i++)o[op++]=br_read_bits(&r,8);}
  else{int v=br_read_bits(&r,7);if(v==127)v+=br_read_bits(&r,8);int match_len=v+3;int first=br_read(&r),offset;
   if(first==0)offset=ro_dec[0];else if(br_read(&r)==0)offset=ro_dec[1];else if(br_read(&r)==0)offset=ro_dec[2];
   else{int mag=br_read_bits(&r,4),bits=mag+5;int no=br_read_bits(&r,bits)+1;ro_dec[2]=ro_dec[1];ro_dec[1]=ro_dec[0];ro_dec[0]=no;offset=no;}
   if(offset<=0||offset>op)break;
   for(int i=0;i<match_len&&op<expected;i++){o[op]=o[op-offset];op++;}
  }
 }
 return op;
}

static double nm(){struct timeval tv;gettimeofday(&tv,NULL);return tv.tv_sec*1000.0+tv.tv_usec/1000.0;}

int main(int ac,char**av){
 if(ac==3){
  FILE*f=fopen(av[1],"rb");fseek(f,0,SEEK_END);long n=ftell(f);fseek(f,0,SEEK_SET);
  uint8_t*d=malloc(n+65536);fread(d,1,n,f);fclose(f);
  uint8_t*o=malloc(n*2+65536);double t0=nm();int32_t cs=enc(d,(int32_t)n,o,n*2+65536);double t1=nm()-t0;
  int tt;if(cs<0){tt=-cs;}else if(cs>0&&cs<n+8){o[0]='V';o[1]='L';o[2]='Z';o[3]='X';
   o[4]=((int32_t)n>>24)&0xFF;o[5]=((int32_t)n>>16)&0xFF;o[6]=((int32_t)n>>8)&0xFF;o[7]=(int32_t)n&0xFF;tt=cs;
  }else{o[0]='V';o[1]='L';o[2]='Z';o[3]='R';memcpy(o+8,d,n);
   o[4]=((int32_t)n>>24)&0xFF;o[5]=((int32_t)n>>16)&0xFF;o[6]=((int32_t)n>>8)&0xFF;o[7]=(int32_t)n&0xFF;tt=n+8;}
  FILE*f2=fopen(av[2],"wb");fwrite(o,1,tt,f2);fclose(f2);
  double rt=(1.0-(double)tt/(double)n)*100.0;printf("OK %ld %d %.2f %.3f\n",n,tt,rt,t1);free(d);free(o);
 }else if(ac==4&&strcmp(av[1],"-d")==0){
  FILE*f=fopen(av[2],"rb");fseek(f,0,SEEK_END);long n=ftell(f);fseek(f,0,SEEK_SET);
  uint8_t*c=malloc(n+64);fread(c,1,n,f);fclose(f);
  uint8_t*o;int32_t dl=-1;
  if(memcmp(c,"VRLE",4)==0){
   // ═══ FIX: Pre-parse VRLE count to know exact allocation size ═══
   int32_t vct=0,sh=0,pos=5;
   while(pos<(int32_t)n){vct|=(c[pos]&0x7F)<<sh;sh+=7;if(!(c[pos]&0x80))break;pos++;}
   if(vct>0&&vct<268435456){
    o=malloc(vct+65536);
    dl=vrle_dec(c,(int32_t)n,o);
    if(dl<=0){free(o);o=NULL;}
   }
  }else{
   int32_t expected=(c[4]<<24)|(c[5]<<16)|(c[6]<<8)|c[7];
   o=malloc(expected+65536);
   if(memcmp(c,"VLZX",4)==0)dl=vlzx_dec(c,(int32_t)n,o,expected);
   else if(memcmp(c,"VLZR",4)==0){dl=expected;memcpy(o,c+8,dl);}
  }
  if(dl<=0){free(c);free(o);return 1;}
  FILE*f2=fopen(av[3],"wb");fwrite(o,1,dl,f2);fclose(f2);
  printf("OK %ld %d\n",n,dl);free(c);free(o);
 }else{printf("vlzx <in> <out>   — compress\nvlzx -d <in> <out> — decompress\n");return 1;}
 return 0;
}