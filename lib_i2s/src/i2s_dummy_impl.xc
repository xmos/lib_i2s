// Copyright (c) 2015-2016, XMOS Ltd, All rights reserved
#include <i2s.h>

#undef i2s_tdm_master
void i2s_tdm_master(client interface i2s_callback_if i,
        out buffered port:32 i2s_dout[num_i2s_out],
        static const size_t num_i2s_out,
        in buffered port:32 i2s_din[num_i2s_in],
        static const size_t num_i2s_in,
        out buffered port:32 i2s_bclk,
        out buffered port:32 i2s_lrclk,
        out buffered port:32 tdm_fsync,
        out buffered port:32 tdm_dout[num_tdm_out],
        size_t num_tdm_out,
        in buffered port:32 tdm_din[num_tdm_in],
        size_t num_tdm_in,
        clock clk_bclk,
        clock clk_mclk)
{}

#undef i2s_master
void i2s_master(client i2s_callback_if i2s_i,
                out buffered port:32 (&?p_dout)[num_out],
                static const size_t num_out,
                in buffered port:32 (&?p_din)[num_in],
                static const size_t num_in,
                out buffered port:32 p_bclk,
                out buffered port:32 p_lrclk,
                clock bclk,
                const clock mclk)
{}

#if defined(__XS2A__)

#undef i2s_frame_master
void i2s_frame_master(client i2s_frame_callback_if i2s_i,
                out buffered port:32 (&?p_dout)[num_out],
                static const size_t num_out,
                in buffered port:32 (&?p_din)[num_in],
                static const size_t num_in,
                out port p_bclk,
                out buffered port:32 p_lrclk,
                in port p_mclk,
                clock bclk)
{}

#endif // __XS2A__

#undef i2s_slave
void i2s_slave(client i2s_callback_if i2s_i,
        out buffered port:32 (&?p_dout)[num_out],
        static const size_t num_out,
        in buffered port:32 (&?p_din)[num_in],
        static const size_t num_in,
        in port p_bclk,
        in buffered port:32 p_lrclk,
        clock bclk)
{
}

#undef tdm_master
void tdm_master(client interface i2s_callback_if tdm_i,
        out buffered port:32 p_fsync,
        out buffered port:32 (&?p_dout)[num_out],
        size_t num_out,
        in buffered port:32 (&?p_din)[num_in],
        size_t num_in,
        clock clk){
}
