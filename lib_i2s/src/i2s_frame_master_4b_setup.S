// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

/*
void i2s_frame_master_4b_setup(
    int32_t out_samps[],
    int32_t in_samps[],
    out buffered port:32 ?p_dout,
    in buffered port:32 ?p_din,
    clock bclk,
    out buffered port:32 p_lrclk
    );
*/

#define NSTACKWORDS     (8)
#define FUNCTION_NAME   i2s_frame_master_4b_setup

#define out_array       r0
#define inp_array       r1
#define out_port        r2
#define inp_port        r3
#define bt_clock        r4
#define lr_clock        r5
#define a               r6
#define b               r7
#define c               r8
#define d               r9
#define e               r10
#define f               r11

.text
.issue_mode dual
.align 4

.cc_top FUNCTION_NAME.function,FUNCTION_NAME

FUNCTION_NAME:
    dualentsp NSTACKWORDS
  // Store registers r4 upwards to the stack.
    std    bt_clock, lr_clock, sp[0]
    std    a, b, sp[1]
    std    c, d, sp[2]
    std    e, f, sp[3]

  // Retrieve final two arguments to function
    ldw    bt_clock, sp[9]
    ldw    lr_clock, sp[10]
  
  // Split into input-only, output-only, or input-output body implementations
  // If the input port is nulled (0), only set up an output. Otherwise, proceed
  // to set up an input.
    bf     inp_port, i2s_frame_master_4b_setup_out_body

i2s_frame_master_4b_setup_in_body:
  // If we are here and the output port is not null (non-0), then both in and 
  // out are in use. Jump to the input-output implementation.
  // Otherwise, just set up an input.
    bt     out_port, i2s_frame_master_4b_setup_in_out_body

  // Start the bit clock
    setc   res[bt_clock], 0xF

  // Output 32 1s to lr_clock
    mkmsk  e, 32                     
    out    res[lr_clock], e 

  // Input samples
  {                                  ; in     f, res[inp_port] }
  {                                  ; in     e, res[inp_port] }
  {                                  ; in     d, res[inp_port] }
  {                                  ; in     c, res[inp_port] }

  // Unzip the recieved even samples as required
  // aeim bfjn cgko dhlp -> (abcd) (efgh) (ijkl) (mnop)
    unzip  e, f, 0
    unzip  c, d, 0
    unzip  d, f, 0
    unzip  c, e, 0 

  // Bit-reverse and store the recieved even samples
  {                                  ; bitrev f, f             }
  { stw    f, inp_array[6]           ; bitrev e, e             } 
  { stw    e, inp_array[4]           ; bitrev d, d             } 
  { stw    d, inp_array[2]           ; bitrev c, c             } 
  { stw    c, inp_array[0]           ;                         }

  // Input the first two odd samples. As we are returning from this function, 
  // we must store these recieved samples in memory to pick up later.
  {                                  ; in     f, res[inp_port] }
  { stw    f, inp_array[1]           ; in     e, res[inp_port] }
  { stw    e, inp_array[3]           ;                         }

  // Jump to the common end section
    bu     i2s_frame_master_4b_setup_final 

i2s_frame_master_4b_setup_out_body:
  // Load and bit-reverse the even 32-bit samples we intend to send
  // Generate 32 bits of 1 for the lrclock
  { ldw    a, out_array[0]           ;                         }
  { ldw    b, out_array[2]           ; bitrev a, a             } 
  { ldw    c, out_array[4]           ; bitrev b, b             } 
  { ldw    d, out_array[6]           ; bitrev c, c             } 
  { mkmsk  e, 32                     ; bitrev d, d             }

  // Zip the even samples as required to send in parallel on a 4b port
  // (abcd) (efgh) (ijkl) (mnop) -> aeim bfjn cgko dhlp
    zip    a, c, 0
    zip    b, d, 0
    zip    a, b, 0
    zip    c, d, 0  

  // Load and bit-reverse the odd 32-bit samples we intend to send
  // Output 32 1s to the lrclock transfer register
  // Output the even samples
  // Start the bit clock
  { ldw    d, out_array[7]           ; out    res[out_port], d }
    setc   res[bt_clock], 0xF
  { ldw    c, out_array[5]           ; out    res[out_port], c }
  { bitrev d, d                      ; out    res[lr_clock], e }
  { ldw    b, out_array[3]           ; out    res[out_port], b }
  { bitrev c, c                      ;                         }
  { ldw    a, out_array[1]           ; out    res[out_port], a }
  { bitrev b, b                      ; bitrev a, a             }

  // Zip the odd samples as required to send in parallel on a 4b port
    zip    a, c, 0
    zip    b, d, 0
    zip    a, b, 0
    zip    c, d, 0  
    
  // Output the odd samples. At this point, we have transmitted all
  // 8 samples, and must call the send callback to recieve the next batch.
  {                                  ; out    res[out_port], d }
  {                                  ; out    res[out_port], c }
  {                                  ; out    res[out_port], b }
  {                                  ; out    res[out_port], a }

  // Jump to the common end section
    bu     i2s_frame_master_4b_setup_final 

i2s_frame_master_4b_setup_in_out_body:
  // Load and bit-reverse the even 32-bit samples we intend to send
  // Generate 32 bits of 1 for the lrclock
  { ldw    a, out_array[0]           ;                         }
  { ldw    b, out_array[2]           ; bitrev a, a             } 
  { ldw    c, out_array[4]           ; bitrev b, b             } 
  { ldw    d, out_array[6]           ; bitrev c, c             } 
  { mkmsk  e, 32                     ; bitrev d, d             }

  // Zip the even samples as required to send in parallel on a 4b port
  // (abcd) (efgh) (ijkl) (mnop) -> aeim bfjn cgko dhlp
    zip    a, c, 0
    zip    b, d, 0
    zip    a, b, 0
    zip    c, d, 0  

  // Load and bit-reverse the odd 32-bit samples we intend to send
  // Output 32 1s to the lrclock transfer register
  // Output the even samples
  // Start the bit clock
  // Input the first even sample - this must happen here to meet timing
  { ldw    d, out_array[7]           ; out    res[out_port], d }
    setc   res[bt_clock], 0xF
  { ldw    c, out_array[5]           ; out    res[out_port], c }
  { bitrev d, d                      ; out    res[lr_clock], e }
  { ldw    b, out_array[3]           ; out    res[out_port], b }
  { bitrev c, c                      ; in     f, res[inp_port] }
  { ldw    a, out_array[1]           ; out    res[out_port], a }
  { bitrev b, b                      ; bitrev a, a             }

  // Zip the odd samples as required to send in parallel on a 4b port
    zip    a, c, 0
    zip    b, d, 0
    zip    a, b, 0
    zip    c, d, 0  
    
  // Output the first two odd samples
  // Input the remaining even samples
  {                                  ; in     e, res[inp_port] }
  {                                  ; out    res[out_port], d }
  {                                  ; in     d, res[inp_port] }
  {                                  ; out    res[out_port], c }
  {                                  ; in     c, res[inp_port] }

  // Unzip the recieved even samples as required
  // aeim bfjn cgko dhlp -> (abcd) (efgh) (ijkl) (mnop)
    unzip  e, f, 0
    unzip  c, d, 0
    unzip  d, f, 0
    unzip  c, e, 0 

  // Bit-reverse and store the recieved even samples
  {                                  ; bitrev f, f             }
  { stw    f, inp_array[6]           ; bitrev e, e             } 
  { stw    e, inp_array[4]           ; bitrev d, d             } 
  { stw    d, inp_array[2]           ; bitrev c, c             } 
  { stw    c, inp_array[0]           ;                         }

  // Output the remaining odd samples. At this point, we have transmitted all
  // 8 samples, and must call the send callback to recieve the next batch.
  // Input the first two odd samples. As we are returning from this function
  // in order to call the send callback, we must store these recieved samples in
  // memory to pick up later.
  {                                  ; out    res[out_port], b }
  {                                  ; in     f, res[inp_port] }
  { stw    f, inp_array[1]           ; out    res[out_port], a }
  {                                  ; in     e, res[inp_port] }
  { stw    e, inp_array[3]           ;                         }

  // Continue to common end section

i2s_frame_master_4b_setup_final:
  // Restore registers and return.
    ldd    bt_clock, lr_clock, sp[0] 
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