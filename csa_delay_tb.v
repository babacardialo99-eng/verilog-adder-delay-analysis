// iu = stage# e.g stage0, stage1...
// timeout is a safety counter used to prevent an infinite simulation loop.
`timescale 1ns/100ps

// Sweep critical-path (worst-case ripple) delay vs N for different adders

// ============================================================
// Generic Testbench Template (RCA / CBA / CSA/ any ILA-style adder)
// Assumptions:
//   - DUT ports: X, PS, Z, NS
//   - Packing per stage: X[i*n +: n] = {B, A}
//   - A and B are m bits each, so n must be 2*m
//   - Total adder width W = N*m
// ============================================================

// -------- One test case module (parameterized by N) ----------
module tb_csa_case #(parameter integer N = 4) (); // TODO: rename module (e.g., tb_rca_case, tb_cba_case)

  // -------------------------
  // TODO 1: Choose parameters
  // -------------------------
  // N = number of stages (RCA bit-slices or CBA blocks)
  // m = sum bits produced per stage (RCA: m = 1, CBA(4-bit blocks): m=4)
  // n = width of X per stage )
  // k = state width (usually 1 for carry chain)

  localparam integer m  =   4;    // bitwidth of sum output of one stage
  localparam integer n  =   8;    // bitwidth of X input of one stage  
  localparam integer k  =   1;    // bitwidth of PS input and NS output of one stage
  localparam integer W  = N*m;  // total bitwidth of sum output of the entire ILA     

  // -------------------------
  // DUT signals
  // ------------------------- 
  reg  [n*N-1:0] X;    // primary input bus (all stages)
  reg  [k-1:0]  PS;    // global input state (Cin for stage0)
  wire [m*N-1:0] Z;    // sum bus (all stages concatenated)
  wire [k-1:0]  NS;    // final carry-out.

  // combined result = {Cout, Sum}
  wire [W:0] RESULT; 
  assign RESULT = {NS, Z};

  // -------------------------
  // TODO 2: Instantiate DUT
  // -------------------------

  // Ensure parameters match DUT parameter names.
    CSA #(.N(N), .m(m), .n(n), .k(k)) dut (
       .X(X),   // connect the input port(X) to the signal (X)
       .PS(PS),  
       .Z(Z), 
       .NS(NS)
     );

  // -------------------------
  // Derived A and B from X
  // -------------------------
  // We do NOT choose A,B directly. We choose X.
  // Then we reconstruct A and B from X using the same packing as the DUT.
  reg [W-1:0] A, B;
  reg [W: 0] expected;

  // Loop indices must be different for different always/initial blocks
  integer iu;        // unpack index
  integer timeout;  

  // use real for portability
  real t0, t1;       // for timing measurement
  real settle_time;  // time for output to settle after input change

 
// ------------------------------------------------------------
// TODO 3: Unpack the packed input bus X into A and B.
// ------------------------------------------------------------
always @(*) begin
  for (iu = 0; iu < N; iu = iu + 1) begin
  // Replace this comment block with your unpacking logic.
  // Hint: You typically need a loop over stages i=0..N-1 and part-selects
  // like: X[i*n +: m] or X[i*n + m +: m].
    A[iu*m +: m] = X[iu*n +: m];        // lower m bits = A
    B[iu*m +: m] = X[iu*n + m +: m];    // upper m bits = B
  end
end
  // ------------------------------------------------------------
  // Golden model
  // expected = A + B + Cin
  // ------------------------------------------------------------
   
  always @(*) begin
    expected = {1'b0, A} + {1'b0, B} + PS;
  end

  initial begin
    // Stagger each case in time so outputs don't interleave badly
    // (each instance waits N*50 ns before starting)
     # (N * 50);

    $display ("---------------------------");
    $display ("CSA sweep case: W=%0d bits",  W);// change <design> to your design name (e.g., RCA, CBA, CSA)

    // init
    X  = {n*N{1'b0}};
    PS = 1'b0;
    #5;

    // -------------------------
    // Worst-case ripple stimulus:
    // First block in generates carry, all other blocks propagate it:
    // -------------------------
    // Build X directly (stage slice is 2 bits: {B,A} by your unpack logic)
    // i=0 (LSB): A0=1, B0=1
    // i>0:       Ai=1, Bi=0
    for (iu = 0; iu < N; iu = iu + 1) begin
      if (iu == 0)    
        X[iu*n +: n] = {4'b1111, 4'b1111}; // {B0=1 --> generate a carry, A0=1 -->propagate incoming carry }
      else          // { B          A } 
        X[iu*n +: n] = {4'b0000, 4'b1111}; // {Bi=0-->do not generate a carry , Ai=1 propagate incoming carry}
    end
    PS = 1'b0;
  
    // Measure time-to-correct-result
    t0 = $realtime;

    timeout = 0;
    while ((RESULT !== expected) && (timeout < 100000)) begin
      #1;
      timeout = timeout + 1;
    end

    t1 = $realtime;
    settle_time = (t1 - t0);

    if (RESULT !== expected) begin
      $display("W=%0d TIMEOUT: RESULT=0x%0h expected=0x%0h", W, RESULT, expected);
  
      $fdisplay(tb_CSA_sweep.csv_fd, "%0d,%0d", W, -1);
    end else begin
      $display("W=%0d PASS: RESULT=0x%0h expected=0x%0h  critical path delay=%0.2f ns",
                W,  RESULT, expected, settle_time);

      // Write CSV row: W,delay_ns
      $fdisplay(tb_CSA_sweep.csv_fd, "%0d,%0.4f", W, settle_time); // change <design> to your design name (e.g., RCA, CBA, CSA)
    end

  $display("W=%0d A=0x%0h B=0x%0h Cin=%b", W, A, B, PS);
  $display("--------------------------------------------------");
  end
  endmodule


// ------ Top that instantiates all N cases ----------
  module tb_CSA_sweep;
  integer csv_fd;

  initial begin 
    $timeformat(-9, 2, " ns", 10);
    $dumpfile ("tb_CSA_sweep.vcd");
    $dumpvars (0, tb_CSA_sweep); // change <design> to your design name (e.g., RCA, CBA, CSA)

    // Create CSV + header
    csv_fd = $fopen("CSA_delay_sweep.csv", "w");
    if (csv_fd == 0) begin
      $display("ERROR: could not open CSA_delay_sweep.csv for write");
      $finish;
    end
    $fdisplay(csv_fd, "Number of bits,delay_ns");
    end


  // Instantiate SWEEP points : This is where you create instances of the test case 
  // module for different values of N (number of stages) and thus different total
  // bitwidths W.
  // Each instance will run the same test logic but with different N and W, allowing you to sweep the critical path delay across a range of adder sizes.
  // TODO 5:
  // Make 6 sweep points for CBA and CSA designs (N=1,2,4,16,32,64)
  // Make 4 sweep points for RCA design (N=4,8,16,64)
  


  // TODO 6: instantiate more cases for N=8,16,64,128

    // Test case for N = 1 stage
    tb_csa_case #(.N(1)) uN1(); 
    
    // Test case for N = 2 stages. 
    tb_csa_case #(.N(2) ) uN2();

    // Test case for N = 4 stages. 
    tb_csa_case #(.N(4) ) uN4();

    // Test case for N = 16 stages.
    tb_csa_case #(.N(16) ) uN16();

    // Test case for N = 32 stages.
    tb_csa_case #(.N(32) ) uN32();
    
    // Test case for N = 64 stages.
    tb_csa_case #(.N(64) ) uN64();


  initial begin
    // rough bound; adjust if needed
    #2000000;  // wait 2,000,000 time units before stoipping the simulation

    // close CSV
    $fclose(csv_fd);

    $finish;
  end

endmodule