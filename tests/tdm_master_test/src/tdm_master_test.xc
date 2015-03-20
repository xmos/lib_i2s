#include <xs1.h>
#include <i2s.h>

typedef struct {
    int offset;
    unsigned sclk_edge_count;
    unsigned channels_per_data_line;
    unsigned sample_rate;
} test_setup;

#define TEST_COUNT (16)

test_setup tests[TEST_COUNT] = {
    {0 , 1,   2, 48000},
    {-1, 1,   2, 48000},
    {0 , 1,   4, 48000},
    {-1, 1,   4, 48000},
    {0 , 1,   8, 48000},
    {-1, 1,   8, 48000},

    {0 , 32,  2, 48000},
    {-1, 32,  2, 48000},
    {0 , 32,  4, 48000},
    {-1, 32,  4, 48000},
    {0 , 32,  8, 48000},
    {-1, 32,  8, 48000},

    {0 , 64,  4, 48000},
    {-1, 64,  4, 48000},
    {0 , 128, 8, 48000},
    {-1, 128, 8, 48000},
};
in port p_sclk  = XS1_PORT_1A;
out buffered port:32 p_fsync = XS1_PORT_1C;

in buffered port:32 p_tdm_din [4] = {XS1_PORT_1D, XS1_PORT_1E, XS1_PORT_1F, XS1_PORT_1G};
out buffered port:32  p_tdm_dout[4] = {XS1_PORT_1H, XS1_PORT_1I, XS1_PORT_1J, XS1_PORT_1K};

clock sclk = XS1_CLKBLK_1;

out port setup_strobe_port = XS1_PORT_1L;
out port setup_data_port = XS1_PORT_16A;
in port  setup_resp_port = XS1_PORT_1M;

#define SAMPLES_PER_FRAME 8

void app(client tdm_if tdm_i)
{
    unsigned x=0;
    tdm_i.start(sclk);
    configure_clock_ref(sclk, 8);
    start_clock(sclk);

    while(1){
        tdm_i.send(x++);
        //tdm_i.receive();
    }


}
#define TDM_NUM_IN 1
#define TDM_NUM_OUT 1

int main()
{
    interface tdm_if tdm_i;
    par {
     tdm_master(tdm_i, p_fsync,
             p_tdm_dout, TDM_NUM_OUT,
             p_tdm_din,TDM_NUM_IN,
             8, 0, 1);
     app(tdm_i);
     par(int i=0;i<7;i++)while(1);
    }

  return 0;
}
