// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

/*
void i2s_frame_master_4b_loop_part_1(
    int32_t out_samps[],
    int32_t in_samps[],
    out buffered port:32 ?p_dout,
    in buffered port:32 ?p_din,
    out buffered port:32 p_lrclk
    );
*/

#define NSTACKWORDS     (8)
#define FUNCTION_NAME   i2s_frame_master_4b_loop_part_1

#define out_array       r0
#define inp_array       r1
#define out_port        r2
#define inp_port        r3
#define lr_clock        r4
#define a               r5
#define b               r6
#define c               r7
#define d               r8
#define e               r9
#define f               r10

.text
.issue_mode dual
.align 4

.cc_top FUNCTION_NAME.function,FUNCTION_NAME

FUNCTION_NAME:
    dualentsp NSTACKWORDS
  // Store registers r4 upwards to the stack.
    stw    lr_clock, sp[0]
    std    a, b, sp[1]
    std    c, d, sp[2]
    std    e, f, sp[3]

  // Retrieve final argument to the function.
    ldw    lr_clock, sp[9]

  // Split into input-only, output-only, or input-output body implementations
  // If the input port is nulled (0), only output. Otherwise, proceed to input
    bf     inp_port, i2s_frame_master_4b_loop_part_1_out_body

i2s_frame_master_4b_loop_part_1_in_body:
  // If we are here and the output port is not null (non-0), then both in and 
  // out are in use. Jump to the input-output implementation.
  // Otherwise, just input.
    bt     out_port, i2s_frame_master_4b_loop_part_1_in_out_body

  // Output 32 bits of 0 for lr clock
    ldc    e, 0
    out    res[lr_clock], e

  // Retrieve the two odd samples we stored earlier, and input the other two
  { ldw    f, inp_array[1] ; in     d, res[inp_port] }
  { ldw    e, inp_array[3] ; in     c, res[inp_port] }
    
  // Unzip the recieved odd samples as required
  // aeim bfjn cgko dhlp -> (abcd) (efgh) (ijkl) (mnop)
    unzip  e, f, 0
    unzip  c, d, 0
    unzip  d, f, 0
    unzip  c, e, 0 

  // Bit-reverse and store the recieved odd samples. At this point, we have
  // recieved all 8 samples and must call the recieve callback to pass these 
  // to the user. 
  {                        ; bitrev f, f             }
  { stw    f, inp_array[7] ; bitrev e, e             } 
  { stw    e, inp_array[5] ; bitrev d, d             } 
  { stw    d, inp_array[3] ; bitrev c, c             } 
  { stw    c, inp_array[1] ;                         }

  // Jump to the common end section
    bu     i2s_frame_master_4b_loop_part_1_final 

i2s_frame_master_4b_loop_part_1_out_body:
  // Load and bit-reverse the even 32-bit samples we intend to send
  // Generate and output 32 bits of 0 for the lrclock
  { ldw    a, out_array[0] ; ldc    e, 0             }
  { ldw    b, out_array[2] ; out    res[lr_clock], e } 
  { ldw    c, out_array[4] ; bitrev a, a             } 
  { ldw    d, out_array[6] ; bitrev b, b             } 
  { bitrev c, c            ; bitrev d, d             }

  // Zip the even samples as required to send in parallel on a 4b port
  // (abcd) (efgh) (ijkl) (mnop) -> aeim bfjn cgko dhlp
    zip    a, c, 0
    zip    b, d, 0
    zip    a, b, 0
    zip    c, d, 0  

  // Output the first two even samples. 
  // Stash the 3rd and 4th even samples for transmission later.
  { stw    a, out_array[0] ; out    res[out_port], d }
  { stw    b, out_array[2] ; out    res[out_port], c }
  
  
  // Jump to the common end section
    bu     i2s_frame_master_4b_loop_part_1_final 

i2s_frame_master_4b_loop_part_1_in_out_body:

  // Load and bit-reverse the even 32-bit samples we intend to send
  // Generate and output 32 bits of 0 for the lrclock
  { ldw    a, out_array[0] ; ldc    e, 0             }
  { ldw    b, out_array[2] ; out    res[lr_clock], e } 
  { ldw    c, out_array[4] ; bitrev a, a             } 
  { ldw    d, out_array[6] ; bitrev b, b             } 
  { bitrev c, c            ; bitrev d, d             }

  // Zip the even samples as required to send in parallel on a 4b port
  // (abcd) (efgh) (ijkl) (mnop) -> aeim bfjn cgko dhlp
    zip    a, c, 0
    zip    b, d, 0
    zip    a, b, 0
    zip    c, d, 0  

  // We stashed the 1st and 2nd recieved odd samples earlier - retrieve these.
  // Input the 3rd and 4th odd samples.
  // Stash the 3rd and 4th even samples for transmission later.
  { ldw    f, inp_array[1] ; out    res[out_port], d }
  { ldw    e, inp_array[3] ; in     d, res[inp_port] }
  { stw    a, out_array[0] ; out    res[out_port], c }
  { stw    b, out_array[2] ; in     c, res[inp_port] }

  // Unzip the recieved odd samples as required
  // aeim bfjn cgko dhlp -> (abcd) (efgh) (ijkl) (mnop)
    unzip  e, f, 0
    unzip  c, d, 0
    unzip  d, f, 0
    unzip  c, e, 0 

  // Bit-reverse and store the recieved odd samples. At this point, we have
  // recieved all 8 samples and must call the recieve callback to pass these 
  // to the user. 
  {                        ; bitrev f, f             }
  { stw    f, inp_array[7] ; bitrev e, e             } 
  { stw    e, inp_array[5] ; bitrev d, d             } 
  { stw    d, inp_array[3] ; bitrev c, c             } 
  { stw    c, inp_array[1] ;                         }

  // Continue to common end section

i2s_frame_master_4b_loop_part_1_final:
  // Restore registers and return.
    ldw    lr_clock, sp[0]
    ldd    a, b, sp[1]
    ldd    c, d, sp[2]
    ldd    e, f, sp[3]
    retsp NSTACKWORDS


.L_func_end:
.cc_bottom FUNCTION_NAME.function

.globl FUNCTION_NAME
.type FUNCTION_NAME,@function
.set FUNCTION_NAME.nstackwords,NSTACKWORDS;  .global FUNCTION_NAME.nstackwords
.set FUNCTION_NAME.maxcores,1;               .global FUNCTION_NAME.maxcores
.set FUNCTION_NAME.maxtimers,0;              .global FUNCTION_NAME.maxtimers
.set FUNCTION_NAME.maxchanends,0;            .global FUNCTION_NAME.maxchanends