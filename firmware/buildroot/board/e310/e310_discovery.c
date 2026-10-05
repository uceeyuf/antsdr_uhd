/* SPDX-License-Identifier: GPL-3.0-or-later
 * Discovery proxy for the PL endpoint behind a Linux Ethernet bridge.
 * The FPGA owns its IPv4/MAC address. Never assign that IP to the PS.
 * All radio control and sample packets remain on the kernel bridge/DMA path.
 */
#define _DEFAULT_SOURCE
#include <arpa/inet.h>
#include <errno.h>
#include <linux/if_packet.h>
#include <net/ethernet.h>
#include <net/if.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

static unsigned get16(const unsigned char *p) { return (p[0]<<8)|p[1]; }
static void put16(unsigned char *p, unsigned v) { p[0]=v>>8; p[1]=v; }
static unsigned checksum(const unsigned char *p, size_t n) {
    unsigned s=0;
    for (size_t i=0; i+1<n; i+=2) s+=get16(p+i);
    if (n&1) s+=p[n-1]<<8;
    while (s>>16) s=(s&65535)+(s>>16);
    return (~s)&65535;
}
/* Return zero for truncated, fragmented, unrelated or malformed packets. */
static size_t reply(const unsigned char *in, size_t n, unsigned char out[98],
                    const unsigned char ip[4], const unsigned char mac[6],
                    const char *serial) {
    if (n<42 || get16(in+12)!=0x0800 || (in[14]>>4)!=4) return 0;
    unsigned ihl=(in[14]&15)*4;
    if (ihl<20 || n<14+ihl+8 || in[23]!=17) return 0;
    unsigned total=get16(in+16);
    if (total<ihl+8+56 || total>n-14 || (get16(in+20)&0x3fff)) return 0;
    if (checksum(in+14,ihl)!=0) return 0;
    /* Accept endpoint unicast and L2 broadcast discovery (including /24 etc). */
    static const unsigned char broadcast[6]={255,255,255,255,255,255};
    if (memcmp(in+30,ip,4) && memcmp(in,broadcast,6)) return 0;
    const unsigned char *udp=in+14+ihl;
    if (get16(udp+2)!=49100 || get16(udp+4)!=64 || ihl+64>total) return 0;
    static const unsigned char request[16]={0,0,0,'1',0,0,0,'m',0,0,0,'9',0,0,0,'j'};
    if (memcmp(udp+8,request,16)) return 0;
    memset(out,0,98);
    memcpy(out,in+6,6); memcpy(out+6,mac,6); put16(out+12,0x0800);
    out[14]=0x45; put16(out+16,84); out[22]=64; out[23]=17;
    memcpy(out+26,ip,4); memcpy(out+30,in+26,4);
    put16(out+24,checksum(out+14,20));
    put16(out+34,49100); memcpy(out+36,udp,2); put16(out+38,64);
    /* A zero UDP checksum is valid for IPv4. */
    out[45]='1'; out[49]='M'; out[53]='0'; out[57]='c';
    memcpy(out+58,serial,strlen(serial)); memcpy(out+90,"E310",4);
    return 98;
}

static int selftest(void) {
    unsigned char in[98]={0},out[98],ip[4]={192,168,1,10},mac[6]={2,1,2,3,4,5};
    memset(in,255,6); in[6]=2; put16(in+12,0x800);
    in[14]=0x45; put16(in+16,84); in[22]=64; in[23]=17;
    in[26]=192; in[27]=168; in[28]=1; in[29]=20;
    memset(in+30,255,4); put16(in+24,checksum(in+14,20));
    put16(in+34,53000); put16(in+36,49100); put16(in+38,64);
    in[45]='1';in[49]='m';in[53]='9';in[57]='j';
    if(reply(in,98,out,ip,mac,"TEST")!=98 || checksum(out+14,20) ||
       memcmp(out+26,ip,4) || get16(out+36)!=53000 || memcmp(out+90,"E310",4)) return 1;
    for(size_t n=0;n<98;n++) if(reply(in,n,out,ip,mac,"TEST")) return 2;
    in[20]=0x20; if(reply(in,98,out,ip,mac,"TEST")) return 3; in[20]=0;
    in[49]='X'; if(reply(in,98,out,ip,mac,"TEST")) return 4; in[49]='m';
    in[15]=1; if(reply(in,98,out,ip,mac,"TEST")) return 5;
    puts("discovery packet tests PASS"); return 0;
}
int main(int argc,char **argv) {
    if(argc==2 && !strcmp(argv[1],"--selftest")) return selftest();
    if(argc!=5) { fprintf(stderr,"Usage: %s PHYSICAL_IF FPGA_IP FPGA_MAC SERIAL\n",argv[0]);return 2; }
    unsigned char ip[4],mac[6]; unsigned m[6]; char extra;
    if(inet_pton(AF_INET,argv[2],ip)!=1 || strlen(argv[4])<1 || strlen(argv[4])>31 ||
       sscanf(argv[3],"%x:%x:%x:%x:%x:%x%c",m,m+1,m+2,m+3,m+4,m+5,&extra)!=6) return 2;
    for(int i=0;i<6;i++) { if(m[i]>255)return 2; mac[i]=m[i]; }
    if(mac[0]&1) return 2;
    unsigned idx=if_nametoindex(argv[1]); if(!idx) {perror("interface");return 1;}
    int fd=socket(AF_PACKET,SOCK_RAW,htons(ETH_P_ALL)); if(fd<0){perror("socket");return 1;}
    struct sockaddr_ll addr={0}; addr.sll_family=AF_PACKET;addr.sll_protocol=htons(ETH_P_ALL);addr.sll_ifindex=idx;
    if(bind(fd,(struct sockaddr*)&addr,sizeof(addr))<0){perror("bind");close(fd);return 1;}
    for(;;) {
        unsigned char in[2048],out[98]; struct sockaddr_ll peer; socklen_t len=sizeof(peer);
        ssize_t n=recvfrom(fd,in,sizeof(in),0,(struct sockaddr*)&peer,&len);
        if(n<0) {if(errno==EINTR)continue;perror("recvfrom");break;}
        if(peer.sll_pkttype==PACKET_OUTGOING)continue;
        size_t size=reply(in,(size_t)n,out,ip,mac,argv[4]); if(!size)continue;
        addr.sll_halen=6;memcpy(addr.sll_addr,out,6);
        if(sendto(fd,out,size,0,(struct sockaddr*)&addr,sizeof(addr))!=(ssize_t)size)perror("sendto");
    }
    close(fd);return 1;
}
