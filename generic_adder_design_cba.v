`timescale 1ns/100ps
`define Z_DELAY    5   // sum delay
`define NS_DELAY   6   // carry delay
`define AND4_DELAY 3   // delay for 4-input AND gate (for propagate signal)
`define MUX_DELAY  2   // mux delay 

//  This verilog module for a generic ILA.
// The function of each stage must be defined. 

module cba_stage // TODO: replace <design> with your design name (e.g., rca_stage, cba_stage, csa_stage)
   # (
    parameter m = 4,  // Bitwidth of Primary output Z of a stage
    parameter n = 8,  // Bitwidth of Primary input X to stage
    parameter k = 1   // Bitwidth of state input/output
    )
    (input      [n-1:0] X,  // Primary Input to a stage
    input       [k-1:0] PS, // Present State (Carry-in)
    output reg  [k-1:0] NS,  // Next State (Carry-out)
    output reg  [m-1:0]  Z   // Primary Output of a stage (Sum)
    );
        
  

   // ********** STAGE OUTPUT FUNCTION (Sum) **************
   
   function [m-1:0] ZFn(input [n-1:0] InputX, input [k-1:0] PS_in);

      reg [m-1:0] a, b, p, g; // internal variables for sum function( e.g., a, b, propagate, generate)
      reg [m:0]   c;          // internal ripple carries: c[0]..c[m]
      integer j;              // loop variable for sum function

      begin
         // TODO: Decode InputX into operands a and b and compute ZFn.

         // InputX into operands a and b
         a = InputX [m-1:  0]; // lower bit A
         b = InputX [2*m-1:m]; // upper bit B
         // first carry-in
         c[0] = PS_in;
       
         for (j = 0; j < m; j = j + 1) begin
            p[j] = a[j] ^ b[j];
            g[j] = a[j] & b[j]; 
            c[j+1] = g[j]  |  (p[j] & c[j]);
            ZFn[j] = p[j] ^ c[j]; // sum = XOR carry
         end
      
      end
   endfunction //
   

   // ************* STAGE NEXT STATE FUNCTION *********
   
   function [k-1:0] NSFn(input [n-1:0] InputX, input [k-1:0] PS_in);

      reg [m-1:0] a, b, p, g;
      reg [m:0]   c;
      integer j;

      begin
         // TODO: Decode InputX into operands a and b and compute ZFn.

         // InputX into operands a and b
         a = InputX [m-1:  0];  // lower bit A
         b = InputX [2*m-1:m]; // upper bit B
         // first carry-in
         c[0] = PS_in[0];
       
         for (j = 0; j < m; j = j + 1) begin
            p[j] = a[j] ^ b[j];
            g[j] = a[j] & b[j]; 
            c[j+1] = g[j]  |  (p[j] & c[j]);
         end
      //NSFn[0] = c[m]; // assign the last carry of the whole block cell to the whole NSFN
      NSFn = c[m];
      end
   endfunction 
    

   // Z: compute raw sum bus of a stage, then delay it
   // SUM PATH

    wire [m-1:0] Z_comb;           // raw sum before the delay 
    wire [m-1:0]  Z_d;              // delay sum
    assign Z_comb = ZFn(X, PS);    // compute the sum & pass it to the carry(Z_comb)
    assign #`Z_DELAY Z_d = Z_comb; // after a #`Z_DELAY delay time units & thge value is stored Z_d 
    
   // CARRY PATH
    wire [k-1: 0]  NS_comb;     // sum Carry before the  delay
    wire [k-1: 0]     NS_d;  // sum carry after Carry after  delay

    assign NS_comb   = NSFn(X,  PS);
    assign #`NS_DELAY NS_d = NS_comb; // apply delay. 
   
   reg [m-1:0] a, b, p;
   integer j;

always @(*) begin
   a = X[m-1:0];
   b = X[2*m-1:m];

   for (j = 0; j < m; j = j + 1) begin
   p[j] = a[j] ^ b[j];
  end
end

  
    
    // logic for an AND gate (4 inputs AND gate)
    wire P_comb, P_d; // 1 bts wire 
    assign P_comb = &p; // 4 bits propagate signale 
    assign #`AND4_DELAY P_d = P_comb; // 4 INPUTS DELAYS
   
   // MUX logic: 
    wire P_mux_comb;
    wire P_mux_d;
    assign P_mux_comb = P_d ? PS : NS_d;
    assign #`MUX_DELAY P_mux_d = P_mux_comb;

    // Drive outputs
    always @(*) begin
      NS = P_mux_d;
      Z  = Z_d;
    end
endmodule // stage


module CBA       //TODO: replace <design> with your design name (e.g., RCA, CBA, CSA)
  #(parameter N = 4,    // number of stages
    parameter m = 4,    // width of Z(Sum) output of one stage
    parameter n = 8,    // width of X input of one stage
    parameter k = 1     // width of PS(Carry-in) input and NS(Carry-out) output of one stage
    
    )

// there are N stages.  Each stage has a X input that is n-bits wide. So the X input bus to the entire ILA is N*n bits wide
// Similarly, each stage has a Z output that is m-bits wide. So the Z output bus of the entire ILA is N*m bits wide      
    (input  [n*N-1:0]   X,  
     input  [k-1: 0]   PS,
     output [m*N-1:0]   Z,
     output [k-1:  0]   NS
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
	      cba_stage #(.n(n), .k(k), .m(m)) StageInstance(
            .X(X[i*n +: n]), 
            .PS(InternalBus_State[i*k +: k]),
			   .NS(InternalBus_State[(i+1)*k +: k]), 
            .Z(Z[i*m +: m])
       );
      end
   endgenerate
   
   assign RESULT = {NS, Z};
   
endmodule // ILA