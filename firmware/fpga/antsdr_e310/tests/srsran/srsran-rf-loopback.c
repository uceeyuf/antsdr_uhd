// SPDX-License-Identifier: AGPL-3.0-or-later
// Exercise srsRAN's RF API and UHD plugin through the isolated E310 CODEC loopback.
#include <srsran/phy/rf/rf.h>
#include <complex.h>
#include <math.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

static srsran_rf_t rf;
static atomic_uint errors;
static double start_tx;
static const double rate=1920000.0;
static size_t sent;

static void error_cb(void* unused, srsran_rf_error_t error)
{
    (void)unused;
    atomic_fetch_add(&errors,1);
    fprintf(stderr,"RF error type=%d opt=%d\n",error.type,error.opt);
}

static void* transmit(void* unused)
{
    (void)unused;
    float complex wave[8192];
    for (size_t i=0;i<8192;i++) wave[i]=0.1f*cexpf(I*(float)(2*M_PI*(i%64)/64));
    const size_t total=(size_t)(1.2*rate);
    while (sent<total) {
        size_t offset=sent%8192, n=8192-offset;
        if (n>total-sent) n=total-sent;
        double stamp=start_tx+sent/rate;
        int done=srsran_rf_send_timed2(&rf,wave+offset,(int)n,(time_t)stamp,
                                     stamp-floor(stamp),sent==0,sent+n==total);
        if (done<=0) {atomic_fetch_add(&errors,1); break;}
        sent+=(size_t)done;
    }
    return NULL;
}

int main(void)
{
    char args[]="type=ant,addr=192.168.10.3,master_clock_rate=30.72e6,sampling_rate=1.92e6,e310_codec_loopback=1";
    if (srsran_rf_open_devname(&rf,"UHD",args,1)) return 1;
    srsran_rf_register_error_handler(&rf,error_cb,NULL);
    printf("srsRAN RF device: %s\n",srsran_rf_name(&rf));
    const size_t count=(size_t)rate;
    float complex* capture=calloc(count,sizeof(*capture));
    if (!capture) {srsran_rf_close(&rf); return 1;}
    time_t secs; double frac;
    srsran_rf_get_time(&rf,&secs,&frac);
    start_tx=(double)secs+frac+0.3;
    if (srsran_rf_start_rx_stream(&rf,false)) {free(capture);srsran_rf_close(&rf);return 1;}
    pthread_t thread;
    if (pthread_create(&thread,NULL,transmit,NULL)) {free(capture);srsran_rf_close(&rf);return 1;}
    size_t received=0,gaps=0;
    double expected=-1;
    while (received<count) {
        size_t n=count-received;if(n>8192)n=8192;
        int done=srsran_rf_recv_with_time(&rf,capture+received,n,true,&secs,&frac);
        if (done<=0) {atomic_fetch_add(&errors,1);break;}
        const double stamp=(double)secs+frac;
        if (expected>=0 && fabs(stamp-expected)*rate>0.51) gaps++;
        expected=stamp+done/rate;received+=done;
    }
    srsran_rf_stop_rx_stream(&rf);
    pthread_join(thread,NULL);
    usleep(200000); // Let the RF plugin report the final asynchronous events.
    double complex wanted=0, image=0;
    double energy=0;
    size_t used=0;
    for(size_t i=count/2;i<received;i++) {
        double complex osc=cexp(I*2*M_PI*(i%64)/64);
        wanted+=(double complex)capture[i]*conj(osc);
        image+=(double complex)capture[i]*osc;
        energy+=pow(cabs(capture[i]),2);used++;
    }
    double coherent=used && energy>0 ? pow(cabs(wanted),2)/(used*energy) : 0;
    double rejection=20*log10(cabs(wanted)/fmax(cabs(image),1e-20));
    FILE* out=fopen("srsran_rf_capture.fc32","wb");
    int saved=out && fwrite(capture,sizeof(*capture),received,out)==received;
    if(out)fclose(out);
    free(capture);
    int close_status=srsran_rf_close(&rf);
    unsigned event_errors=atomic_load(&errors);
    int pass=saved && !close_status && received==count && sent==(size_t)(1.2*rate)
        && !event_errors && !gaps && coherent>0.99 && rejection>40;
    printf("srsRAN_RF_UHD_CODEC rate=%.0f tx=%zu rx=%zu rf_errors=%u timestamp_gaps=%zu coherent=%.9f image_db=%.3f\n%s\n",
        rate,sent,received,event_errors,gaps,coherent,rejection,pass?"PASS":"FAIL");
    return pass?0:1;
}
