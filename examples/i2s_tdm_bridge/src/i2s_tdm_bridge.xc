#include <xs1.h>
#include <i2s.h>
#include <stdlib.h>
#include <stdio.h>

in port p_mclk  = XS1_PORT_1A;

//i2s Resources
out buffered port:32 p_bclk = XS1_PORT_1B;
out buffered port:32 p_lrclk = XS1_PORT_1C;

in buffered port:32   p_i2s_din [4] = {XS1_PORT_1D, XS1_PORT_1E, XS1_PORT_1F, XS1_PORT_1G};
out buffered port:32  p_i2s_dout[4] = {XS1_PORT_1H, XS1_PORT_1I, XS1_PORT_1J, XS1_PORT_1K};

clock mclk = XS1_CLKBLK_1;
clock bclk = XS1_CLKBLK_2;

//TDM Resources
out buffered port:32 p_fsync = XS1_PORT_1L;

in buffered port:32   p_tdm_din [1] = {XS1_PORT_1M};
out buffered port:32  p_tdm_dout[1] = {XS1_PORT_1N};

clock sclk = XS1_CLKBLK_3;

#define I2S_NUM_IN  4
#define I2S_NUM_OUT 4
#define TDM_NUM_IN  1
#define TDM_NUM_OUT 1
#define I2S_MODE    I2S_MODE_LEFT_JUSTIFIED
#define TDM

[[distributable]]
void app(server interface i2s_callback_if i2s_i, client tdm_if tdm_i){
    unsigned x=0;

    tdm_i.configure(sclk);
    configure_clock_ref(sclk, 64);
    stop_clock(sclk);
    unsafe {
      unsafe clock u_mclk = mclk;
      configure_clock_ref((clock) u_mclk, 64);
      start_clock((clock) u_mclk);
    }

    while(1){
        select {
        //i2s has recieved something
        case i2s_i.receive(size_t index, int32_t sample):{
            start_clock(sclk);
            tdm_i.send(sample);
            break;
        }
        //i2s wants to send something
        case i2s_i.send(size_t index) -> int32_t r:{

            // r = tdm_i.receive();
            r=x++;
            break;
        }
        case i2s_i.frame_start(unsigned timestamp, unsigned &restart):{

            break;
        }
        case i2s_i.init(unsigned & mclk_bclk_ratio, i2s_mode & mode):{
            mclk_bclk_ratio = 4;
            mode = 1;
            break;
        }
        }
    }
}


int main(){
    interface i2s_callback_if i2s_i;
    interface tdm_if tdm_i;
    set_clock_on(mclk);
    configure_clock_ref(mclk, 64);

    par {
        tdm_master(tdm_i, p_fsync, p_tdm_dout, TDM_NUM_OUT, p_tdm_din,
                TDM_NUM_IN, 8, 0, 1);
        app(i2s_i, tdm_i);
        i2s_master(i2s_i, p_i2s_dout, I2S_NUM_OUT, p_i2s_din, I2S_NUM_IN,
                p_bclk, p_lrclk, bclk, mclk);
        par(int i=0;i<7;i++)while(1);
    }
    return 0;
}


