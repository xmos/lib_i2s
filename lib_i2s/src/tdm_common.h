// Copyright 2015-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#ifndef TDM_COMMON_H_
#define TDM_COMMON_H_
#include <xclib.h>

#define TDM_MAX_CHANNELS_PER_DATA_LINE (16)

static void make_fsync_mask(
        unsigned fsync_mask[],
        int offset,
        unsigned sclk_edge_count,
        unsigned channels_per_data_line){

    unsigned hi_edge = (offset)%(channels_per_data_line*32);
    unsigned lo_edge = (sclk_edge_count+offset)%(channels_per_data_line*32);

    unsigned bit_no = 0;
    unsigned w;
    for(unsigned i=0;i<channels_per_data_line;i++){
        for(unsigned j=0;j<32;j++){
            w<<=1;
            if(lo_edge > hi_edge)
                w += ((bit_no>=hi_edge)&&(bit_no < lo_edge));
            else
                w += ((bit_no>=hi_edge)||(bit_no < lo_edge));
            bit_no++;
        }
        fsync_mask[i] = bitrev(w);
    }
}

#endif /* TDM_COMMON_H_ */
