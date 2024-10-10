// Copyright 2015-2024 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <i2s.h>


#undef i2s_frame_master
void i2s_frame_master(
                CLIENT_INTERFACE(i2s_frame_callback_if, i2s_i),
                // unsigned *p_dout,
                // out_buffered_port_32_t *p_dout,
                NULLABLE_ARRAY_OF_SIZE(out_buffered_port_32_t, p_dout, num_out),
                // out buffered port:32 (&?p_dout)[num_out],
                static_const_size_t num_out,
                // unsigned *p_din,
                // in_buffered_port_32_t *p_din,
                NULLABLE_ARRAY_OF_SIZE(in_buffered_port_32_t, p_din, num_in),
                // in buffered port:32 (&?p_din)[num_in],
                static_const_size_t num_in,
                static_const_size_t num_data_bits,
                // unsigned p_bclk,
                out_port_t p_bclk,
                out_buffered_port_32_t p_lrclk,
                in_port_t p_mclk,
                clock bclk)
{
}

#undef i2s_frame_slave
void i2s_frame_slave(CLIENT_INTERFACE(i2s_frame_callback_if, i2s_i),
                NULLABLE_ARRAY_OF_SIZE(out_buffered_port_32_t, p_dout, num_out),
                static_const_size_t num_out,
                NULLABLE_ARRAY_OF_SIZE(in_buffered_port_32_t, p_din, num_in),
                static_const_size_t num_in,
                static_const_size_t num_data_bits,
                in_port_t p_bclk,
                in_buffered_port_32_t p_lrclk,
                clock bclk)
{
}

#undef tdm_master
void tdm_master(CLIENT_INTERFACE(tdm_callback_if, tdm_i),
                out_buffered_port_32_t p_fsync,
                NULLABLE_ARRAY_OF_SIZE(out_buffered_port_32_t, p_dout, num_out),
                static_const_size_t num_out,
                NULLABLE_ARRAY_OF_SIZE(in_buffered_port_32_t, p_din, num_in),
                static_const_size_t num_in,
                clock clk)
{
}
