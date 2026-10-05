/* SPDX-License-Identifier: GPL-3.0-or-later
 * Program the PL Ethernet endpoint after the nixge interface has been opened.
 */
#define _DEFAULT_SOURCE
#include <arpa/inet.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <sys/mman.h>
#include <unistd.h>
int main(int argc,char **argv) {
    struct in_addr ip; unsigned m[6]; char extra;
    if(argc!=3 || inet_pton(AF_INET,argv[1],&ip)!=1 ||
       sscanf(argv[2],"%x:%x:%x:%x:%x:%x%c",m,m+1,m+2,m+3,m+4,m+5,&extra)!=6) {
        fprintf(stderr,"Usage: %s FPGA_IP FPGA_MAC\n",argv[0]);return 2;
    }
    for(int i=0;i<6;i++) if(m[i]>255)return 2;
    if((m[0]&1) || !(m[0]|m[1]|m[2]|m[3]|m[4]|m[5]))return 2;
    int fd=open("/dev/mem",O_RDWR|O_SYNC);if(fd<0){perror("/dev/mem");return 1;}
    volatile uint32_t *r=mmap(0,0x2000,PROT_READ|PROT_WRITE,MAP_SHARED,fd,0x40005000);
    if(r==MAP_FAILED){perror("mmap");close(fd);return 1;}
    r[0x1020/4]=0; /* disable optional bridge-address override */
    r[0]=(m[2]<<24)|(m[3]<<16)|(m[4]<<8)|m[5]; r[1]=(m[0]<<8)|m[1];
    r[0x1000/4]=ntohl(ip.s_addr); r[0x1004/4]=49153;
    __sync_synchronize(); r[2]=1; __sync_synchronize();
    int ok=r[0x1000/4]==ntohl(ip.s_addr) && r[2]==1;
    munmap((void*)r,0x2000);close(fd);
    if(!ok){fprintf(stderr,"PL register readback mismatch\n");return 1;}
    return 0;
}
