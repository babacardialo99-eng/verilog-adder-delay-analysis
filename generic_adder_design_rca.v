/*
NSFn(X, PS) = calculates the carry-out of the stage.
Z → delayed by Z_DELAY
NS → delayed by NS_DELAY

NSFn(X,PS) → raw carry
      ↓
NS_comb   → carry before delay
      ↓
NS_d      → carry after delay
      ↓
NS        → final stage output
Z  --> sum 
NS --> carry 
SUM PATH
ZFn        // Function that computes the raw sum of this stage: Sum = A ⊕ B ⊕ Carry_in
 ↓
Z_comb     // Wire storing the immediate (combinational) sum before any delay is applied
 ↓
Z_DELAY    // Propagation delay of the sum logic (models gate delay defined by `Z_DELAY`)
 ↓
Z_d        // Delayed version of the sum; Z_comb appears here after Z_DELAY time units
 ↓
Z          // Final stage output for the sum (the delayed sum that leaves the stage)


CARRY PATH
NSFn        // Function that computes the raw carry-out of the stage after ripple carry calculation
 ↓
carry_comb  // Wire holding the immediate carry result before delay (raw carry signal)
 ↓
NS_DELAY    // Propagation delay of the carry logic (models carry gate delay defined by `NS_DELAY`)
 ↓
carry_d     // Delayed carry signal; carry_comb appears here after NS_DELAY time units
 ↓
NS          // Final carry-out of the stage; this becomes the carry-in for the next stage

// stages path:
SUM PATH
ZFn → Z_comb → Z_DELAY → Z_d → Z

CARRY PATH
NSFn → NS_comb → NS_DELAY → NS_d → NS
*/
`timescale 1ns/100ps
`define Z_DELAY  5   // sum delay
`define NS_DELAY 6   // carry delay 
`define AND4_DELAY 3 // delay for 4-input AND gate (for propagate signal)
`define MUX_DELAY  2 // mux delay 

//  This verilog module for a generic ILA.
// The function of each stage must be defined. 

module rca_stage //TODO: replace <design> with your design name (e.g., rca_stage, cba_stage, csa_stage)
  #(
    parameter m = 4,   // Bitwidth of Primary output Z of a stage
    parameter n = 8,   // Bitwidth of Primary input X to stage
    parameter k = 1   // Bitwidth of state input/output
    
    )
   (input      [n-1:0] X,  // Primary Input to a stage
    input      [k-1:0] PS, // Present State (Carry-in)
    output reg [k-1:0] NS, // Next State (Carry-out)
    output reg [m-1:0] Z   // Primary Output of a stage (Sum)
    );
        

   //  NS and Z functions must be defined.

   // ********** STAGE OUTPUT FUNCTION (Sum) **************
   
   function [m-1:0] ZFn(input [n-1:0] InputX, input [k-1:0] PS_in);

      reg [m-1:0] a, b, p, g; // internal variables for sum function( e.g., a, b, propagate, generate)
      reg [m:0]   c;          // internal ripple carries: c[0]..c[m]
      integer j;              // loop variable for sum function

      begin //me: X is packed as  = {B, A}
      // Decode InputX into operands a and b and compute ZFn.
      a = InputX [m-1: 0];    // lower  4 bits
      b = InputX [2*m-1:m];   // upper  4 bits

      // propagate & generate 
      p = a ^ b;    // propagate a and b
      g = a & b;    // generate 

      // first carry
      c[0] = PS_in; 
      
      // we compute the generate & propagate)( the carries)
      // m = sum carry of 1 stage(c0 → bit0 ... c4 → final carry) 
      for (j = 0; j < m;  j = j + 1) begin 
         c[j+1] = g[j] | (p[j] & c[j]);       
      end
      // compute the sum bits
      ZFn = p ^ c[m-1:0];
      end
   endfunction 
   
// ************* STAGE NEXT STATE FUNCTION *********
function [k-1:0] NSFn(input [n-1:0] InputX, input [k-1:0] PS_in);

   reg [m-1:0] a, b, p, g;
   reg [m:0]   c;
   integer j;

      begin

      // Decode InputX
       a = InputX[m - 1: 0]; 
       b = InputX[2 * m - 1: m]; 

      //  generate & propagate
       p = a ^ b; // propagate
       g = a & b; // generate

       // first carry
       c[0] = PS_in; 

        // compute the sum 
       for (j = 0; j < m; j = j + 1) begin
       c[j + 1] = g[j] | (p[j] & c[j]);
       end

       // final carry output. 
       NSFn = c[m]; 
       end
   endfunction
    

    // ---- Delay modeling as "gate delays" using continuous assigns ----
    // In this part you model the delay of the stage by breaking down the combinational logic into parts and adding delays to each part.
    // The exact breakdown is up to you, but here is a suggested breakdown:

   // Z: compute raw sum bus of a stage, then delay it
    wire [m-1:0] Z_comb;           // Z_comb = wire that stores the value of sum of a stage
    wire [m-1:0]    Z_d;           // sum after stage delay is applied. Z_d = sum signal
    assign Z_comb = ZFn(X, PS);    // compute the raw sum & store it inside Z_comb
    assign #`Z_DELAY Z_d = Z_comb; // assign Z_comb to  Z_d after Z_DELAY time( Z_d holding the sum from here);
    
    // TODO: You need to compute the internal signals (e.g., propagate, generate, carries) with appropriate delays for both sum and carry logic.
    // compute the internal signals both sum and carry logic.
         
    wire [k -1: 0] NS_comb; // carry before the delay
    wire [k -1: 0]    NS_d;  //  NS_d = carry after delay

    assign NS_comb  =  NSFn(X, PS);   // compute the raw carry & store it in NS_comb
    assign #`NS_DELAY NS_d = NS_comb; // NS_d = delayed carry signal so we apply the delay
   
    //Now compute the rest of the delays for sum, carry, and muxes.
    //Note that this part of logic will be different for different adder designs and you need to think carefully.
    //Refer to the diagram of the different adder structure and code this part accordingly.
    //For CSA/CBA designs, you have Muxes too. You are provided with Mux delays. Use them appropriately.

    // Drive outputs
    always @(*) begin
     NS = NS_d;   // assign the delayed carry (NS_d) to the output carry NS
     Z  = Z_d;   // assign the delayed sum (Z_d) to the output sum Z
    end
endmodule // stage


module RCA        //TODO: replace <design> with your design name (e.g., RCA, CBA, CSA)
  #(parameter N = 4,    // number of stages
    parameter m = 4,    // width of Z(Sum) output of one stage
    parameter n = 8,    // width of X input of one stage(X{B, A} where: A = 4 bits, B = 4 bits --> X =8)
    parameter k = 1    // width of PS(Carry-in) input and NS(Carry-out) output of one stage
    
    )

// there are N stages.  Each stage has a X input that is n-bits wide. So the X input bus to the entire ILA is N*n bits wide
// Similarly, each stage has a Z output that is m-bits wide. So the Z output bus of the entire ILA is N*m bits wide      
    (input  [n*N-1:0] X,  
     input  [k-1:0]   PS,
     output [m*N-1:0] Z,
     output [k-1:0]   NS
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
      for (i=0; i < N; i=i+1) begin: GEN
	      rca_stage #(.n(n), .k(k), .m(m)) StageInstance(
            .X(X[i*n +: n]), 
            .PS(InternalBus_State[i*k +: k]),
			   .NS(InternalBus_State[(i+1)*k +: k]), 
            .Z(Z[i*m +: m])
       );
      end
   endgenerate
   
   assign RESULT = {NS, Z};
   
endmodule // ILA