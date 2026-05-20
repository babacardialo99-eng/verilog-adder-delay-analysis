
`timescale 1ns/100ps
`define Z_DELAY    5   // sum delay
`define NS_DELAY   6   // carry delay
`define AND4_DELAY 3  // delay for 4-input AND gate (for propagate signal)
`define MUX_DELAY  2  // mux delay 

 

//  This verilog module for a generic ILA.
// The function of each stage must be defined. 

module csa_stage #( //TODO: replace <design> with your design name (e.g., rca_stage, cba_stage, csa_stage)

    parameter m = 4,   // Bitwidth of Primary output Z of a stage
    parameter n = 8,   // Bitwidth of Primary input X to stage. a[3:0] + b[3:0]
    parameter k = 1    // Bitwidth of state input/output
 )

   (input      [n-1:0] X,  // Primary Input to a stage
    input      [k-1:0] PS, // Present State (Carry-in)
    output reg [k-1:0] NS, // Next State (Carry-out)
    output reg [m-1:0] Z   // Primary Output of a stage (Sum)
   );

   //  NS and Z functions must be defined.

   // ********** STAGE OUTPUT FUNCTION (Sum) **************
   
   function [m-1:0] ZFn(input [n-1:0] InputX, input [k-1:0] PS_in);

      reg [m-1:0] a, b, p, g;   // internal variables for sum function( e.g., a, b, propagate, generate)
      reg [m:0] c;             // internal ripple carries: c[0]..c[m]
      integer j;               // loop variable for sum function

      begin  
         // split the packed input X into operand a and b
         a = InputX [m-1: 0];     // lower 4 bits
         b = InputX [2*m-1: m];   //  upper 4 bits

         p = a ^ b;     // propagate a and b 
         g = a & b;     // generate

         // first carry of the stage(first carry defined) 
         c[0] = PS_in;  

      // we compute the the generate & propagate 
      for (j = 0; j < m; j = j + 1) begin 
          c[j+1] = g[j]  | (p[j] & c[j]);    
      end
      // compute the sum
      ZFn = p ^ c[m-1:0];  // --> sum = (a ^ b) ^ carry
      end 
   endfunction
   
   
   // ************* STAGE NEXT STATE FUNCTION *********
   
   function [k-1:0] NSFn(input [n-1:0] InputX, input [k-1:0] PS_in);

      reg [m-1:0] a, b, p, g;
      reg [m:0] c;
      integer j;

      begin
       // TODO: Decode InputX into operands a and b and compute NSFn.
       // Hint: Use the propagate generate logic for carry computation.
         a = InputX[m-1:0];
         b = InputX[2*m-1:m];
         p = a ^ b;   // propagate 
         g = a & b;   // generate
         c [0] =  PS_in;  //  carry 
         for (j = 0; j < m; j= j + 1) begin 
         c[j+1] = g[j] | (p[j] &  c[j]);  
      end 
       // compute the sum
       NSFn = c[m]; // final carry out.
      end
   endfunction // StageNextStateFn
    
  //============================================================
  // STEP 1: Parallel Computation of both possible outcome(0 and 1)
  // CSA idea: we don’t wait for carry → we guess both cases
  //============================================================

  // Case 1: Assume carry-in (PS) = 0
  wire [m-1:0]   Z0_comb;    // Sum if Cin = 0 (before the delay)
  wire [k-1:0]  NS0_comb;    // carry-out if Cin = 0 (after the delay) 
  
  // Case 2: Assume carry-in (PS) = 1
  wire [m-1:0]   Z1_comb;    // Sum if Cin = 1 (before the delay)
  wire [k-1:0]  NS1_comb;    // carry-out if Cin = 1 (after the delay) 

  // Compute the the SUM assumming  both possibility.
  assign Z0_comb = ZFn(X, 1'b0);  // compute the sum assuming  PS = 0.
  assign Z1_comb = ZFn(X, 1'b1);  // compute the sum assuming  PS = 1.
  

  // Compute the the carry assumming  both possibility. 
  assign NS0_comb = NSFn(X, 1'b0);  // compute the carry assuming PS = 0.
  assign NS1_comb = NSFn(X, 1'b1);  // compute the carry assuming PS = 1.
  

  // STEP 2: Apply Delays (MODEL HARDWARE)
  // ============================================================           
  //  Apply delays to both parallel computations
  // This models the time it takes for adders to produce outputs
  // ============================================================

  // delayed SUM (after Z_DELAY)
  wire [m-1:0] Z0_d; // sum result after delay (Cin=0 path)
  wire [m-1:0] Z1_d; // sum result after delay (Cin=1 path)

  // delayed carries:
  wire [k-1:0] NS0_d; // carry width (k bits)
  wire [k-1:0] NS1_d; // carry width (k bits)

  // APPLY CARRY AND DELAY TO BOTH
  // sum delay path
  assign #`Z_DELAY  Z0_d = Z0_comb; // assuming sum  = 0
  assign #`Z_DELAY  Z1_d = Z1_comb; // assuming sum  = 1

  // carry delay path 
  assign #`NS_DELAY NS0_d =  NS0_comb; // assuming carry = 0 
  assign #`NS_DELAY NS1_d =  NS1_comb;  // assuming carry = 0 
 

   /* ========================================================      
                STEP 3: MUX SELECTION
      Select correct result using actual carry-in (PS)
    ========================================================*/
   wire [m-1:0]  Z_MUX_comb;  // select the sum  before mux delay
   wire [k-1:0]  NS_MUX_comb;  // select the carry before mux delay  

   //if PS(carry-in) = 1, choose path 1(Z1_d) else choose path 0 --> (Z0_d)
   //if PS(carry-in) = 1, choose path 1(NS1_d) else choose path 0 --> (NS0_d)
   assign Z_MUX_comb  = PS ? Z1_d : Z0_d; 
   assign NS_MUX_comb = PS ? NS1_d : NS0_d;

   /* ===================================================      
   STEP 4: MUX DELAY
   Add delay of the multiplexer
   Even selecting takes time in hardware
   =======================================================*/
   wire [m-1:0] Z_final;  // final sum after MUX delay 
   wire [k-1:0] NS_final; // final carry after Mux delay 

   // Execute the MUX delay 
   assign #`MUX_DELAY Z_final  = Z_MUX_comb; 
   assign #`MUX_DELAY NS_final = NS_MUX_comb; 

 /*==========================================================
 STEP 5: Drive outputs of the stage
 ============================================================*/
   
   always @(*) begin
   Z  =  Z_final;    // final sum output of stage
   NS = NS_final;   // final carry output of stage
  end
  endmodule


 // This module builds the full adder by connecting many csa_stage blocks.

module  CSA     // TODO: replace <design> with your design name (e.g., RCA, CBA, CSA)
    #(parameter N =  4,    //  N = number of stages --> 4 stages.
      parameter m =  4,    //  width of Z(Sum) output of one stage
      parameter n =  8,    //  width of X input of one stage
      parameter k =  1     //  carry width is 1 bit
     )

// there are N stages.  Each stage has a X input that is n-bits wide. So the X input bus to the entire ILA is N*n bits wide
// Similarly, each stage has a Z output that is m-bits wide. So the Z output bus of the entire ILA is N*m bits wide      
    (input  [n*N-1:0]  X,  
     input  [k-1:  0] PS,
     output [m*N-1:0]  Z,
     output [k-1:0]    NS
     );

// state is k-bits wide. This is a bundle. We create an internal bus
// of N+1 bundles to connect the output state bundle of stage i to
// the input state bundle of stage i+1.  The output bundle of the last stage (N-1)
// is the primary output state of the ILA
   wire [m*N + k - 1 : 0] RESULT; 
   wire [(N+1)*k-1:0] InternalBus_State;
   genvar i;

   assign InternalBus_State[0 +: k] = PS;   
   assign NS = InternalBus_State[N*k +: k];

   generate
   for (i = 0; i < N; i=i+1) begin: GEN
	      csa_stage #(.n(n), .k(k), .m(m)) StageInstance(
            .X(X[i*n +: n]), 
            .PS(InternalBus_State[i*k +: k]),
			   .NS(InternalBus_State[(i+1)*k +: k]), 
            .Z(Z[i*m +: m])
       );
      end
   endgenerate
   
   assign RESULT = {NS, Z};
   
endmodule // ILA