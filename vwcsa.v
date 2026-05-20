`timescale 1ns/100ps
`define Z_DELAY  5   // sum delay
`define NS_DELAY 6   // carry delay 
`define AND4_DELAY 3 // delay for 4-input AND gate (for propagate signal)
`define MUX_DELAY  2 // mux delay 

// This verilog module for a generic ILA.
// The function of each stage must be defined. 

module vwcsa_stage 
   #(
     parameter m = 1,
     parameter n = 2,
     parameter k = 1
    ) // we will pass m n and k per stage
   (
    input      [n-1:0] X,  // Primary Input to a stage
    input      [k-1:0] PS, // Present State (Carry-in)
    output reg [k-1:0] NS, // Next State (Carry-out)
    output reg [m-1:0]  Z   // Primary Output of a stage (Sum)
    );
      

   //  NS and Z functions must be defined.

   // ********** STAGE OUTPUT FUNCTION (Sum) **************
   
   function [m-1:0] ZFn(input [n-1:0] InputX, input [k-1:0] PS_in);

      reg [m-1:0] a, b, p, g; // internal variables for sum function( e.g., a, b, propagate, generate)
      reg [m:0]   c;          // internal ripple carries: c[0]..c[m]
      integer j;              // loop variable for sum function

      begin //me: X is packed as  = {B, A}
      // Decode InputX into operands a and b and compute ZFn.
      a = InputX [m-1: 0];    // lower m 4 bits
      b = InputX [2*m-1:m];   // upper m  4 bits

      // propagate & generate 
      p = a ^ b;    // propagate a and b
      g = a & b;    // generate 

      // first carry
      c[0] = PS_in[0]; 
      
      // we compute the generate & propagate)( the carries)
      // m = sum carry of 1 stage(c0 → bit0 ... c4 → final carry) 
      for (j = 0; j < m;  j = j + 1) begin 
         c[j+1] = g[j] | (p[j] & c[j]);       
      end
      // compute the sum bits
      ZFn = p ^ c[m-1:0];
      end
   endfunction 



// --- compute for Cin = 0 ---
wire [m-1:0] Z0_comb;
wire [m-1:0] Z0;
wire [k-1:0] NS0_comb;
wire [k-1:0] NS0;

wire [m-1:0] Z1_comb;
wire [m-1:0] Z1;
wire [k-1:0] NS1_comb;
wire [k-1:0] NS1;

assign Z0_comb = ZFn(X, 1'b0);
assign Z1_comb = ZFn(X, 1'b1);

// apply sum delay to both precomputed paths
assign #`Z_DELAY Z0 = Z0_comb;
assign #`Z_DELAY Z1 = Z1_comb;

function [k-1:0] CarryOut(input [n-1:0] InputX, input Cin);
   reg [m-1:0] a, b, p, g;
   reg [m:0] c;
   integer j;
   begin
      a = InputX[m-1:0];
      b = InputX[2*m-1:m];
      p = a ^ b;
      g = a & b;

      c[0] = Cin;
      for (j = 0; j < m; j = j + 1)
         c[j+1] = g[j] | (p[j] & c[j]);

      CarryOut = c[m];
   end
endfunction

assign NS0_comb = CarryOut(X, 1'b0);
assign NS1_comb = CarryOut(X, 1'b1);

assign #`NS_DELAY NS0 = NS0_comb;
assign #`NS_DELAY NS1 = NS1_comb;

    // ---- Delay modeling as "gate delays" using continuous assigns ----
    // In this part you model the delay of the stage by breaking down the combinational logic into parts and adding delays to each part.
    // The exact breakdown is up to you, but here is a suggested breakdown:

// Z: compute raw sum bus of a stage, then delay it
wire [m-1:0] Z_d;
wire [k-1:0] NS_d;

wire [m-1:0] Z_mux;
wire [k-1:0] NS_mux;

assign Z_mux  = PS ? Z1  : Z0;
assign NS_mux = PS ? NS1 : NS0;

assign #`MUX_DELAY Z_d  = Z_mux;
assign #`MUX_DELAY NS_d = NS_mux;
    
    // TODO: You need to compute the internal signals (e.g., propagate, generate, carries) with appropriate delays for both sum and carry logic.
    // compute the internal signals both sum and carry logic.
         

// Drive outputs
always @(*) begin
  Z  = Z_d;
  NS = NS_d;
end
endmodule
        //  top module (VWCSA)

module VWCSA # ( //module parameter list.
    parameter N = 4,
    parameter k = 1,
    parameter W = N*(N+1)/2  // W = 1 + 2 + 3 + ... + N = N(N+1)/2 = Total number of bits in the adder
    )
    ( 
     input   [2*W-1:0]   X,  // w(A)+w(B) = 2W --> reg[2*w -1:0]  
     input  [k-1:0]    PS, //
     output [W-1:0]     Z,
     output [k-1:0]     NS
     );
    
    

     // ------------------------------------------------------------
     // Internal carry bus:
     // connects carry between stages
     // ------------------------------------------------------------
     wire [(N+1)*k-1:0] InternalBus_State;

     // First carry input comes from PS
    assign InternalBus_State[0 +: k] = PS; 

    // Final carry output comes from last stage  
    assign NS = InternalBus_State[N*k +: k];


    
    /*
    mi = how many bit each stage uses 
    stage 0 → mi = 1 	•	stage 1 → mi = 2....... so on
     offset tells us:where this stage starts inside the big buses X and Z
     when the width bchanges we need to know where the each block goes in the overal BUS and 
     thats what offset handles.
    */
    
    genvar i; 
    generate
    for (i=0; i < N; i=i+1) begin: GEN
    /*-------------------------------------------------------
    mi = width of this stage
     Example:
     i=0 → mi=1
     i=1 → mi=2
     i=2 → mi=3
     -------------------------------------------------------*/
	localparam integer  mi = i + 1; // incremente i for each stage(width growth).

  
    /*-------------------------------------------------
    ni = input width for this stage
    X = {B, A} --> so ni = 2 * mi
    -------------------------------------------------- */
    localparam integer ni = 2 * mi; 
    
     
    /*-----------------------------------------------
    offset = starting position of this stage in big bus
    Formula = sum of previous widths
    offset = 0 + 1 + 2 + ... + i = (i*(i+1))/2
    ------------------------------------------------- */
    localparam integer offset = (i * (i + 1) )/2;

     /*-----------------------------------------------
      Build input X for THIS stage:
      lower part = A
      upper part = B
      ------------------------------------------------- */
    vwcsa_stage #(.m(mi), .n(ni), .k(k)) StageInstance(
    .X({
        X[W + offset +: mi],   // B  (Upper half)
        X[offset +: mi]        // A  (lower half)
       }),

       // Carry-in from the previous stage
         .PS(InternalBus_State[i*k +: k]),

       // Carry out to the next stage  
		 .NS(InternalBus_State[(i+1)*k +: k]), 

       // place the sum in correct position in Z. 
         .Z(Z[offset +: mi])
        );
      end
   endgenerate
endmodule // ILA