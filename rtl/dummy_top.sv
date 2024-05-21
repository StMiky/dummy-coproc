// Copyright 2024 Politecnico di Torino.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 2.0 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-2.0. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// File: dummy_top.sv
// Author: Michele Caon
// Date: 21/05/2024
// Description: Dummy coprocessor top-level module

module dummy_top #(
  parameter int unsigned DATA_WIDTH = 32,
  parameter int unsigned MAX_LATENCY = 32,  // power of 2
  parameter int unsigned MAX_PIPE_DEPTH = 32,
  parameter type tag_t = logic,
  // Dependent parameters: do not override
  localparam int unsigned IterCntW = $clog2(MAX_LATENCY),
  localparam int unsigned PipeIdxW = $clog2(MAX_PIPE_DEPTH) + 1
) (
  input logic clk_i,
  input logic rst_ni,
  input logic flush_i,

  // Input interface
  input  logic                                    valid_i,
  output logic                                    ready_o,
  input  dummy_pkg::coproc_ctl_t                  ctl_i,    // coprocessor mode control
  input  tag_t                                    tag_i,    // operation tag
  input  logic                   [DATA_WIDTH-1:0] rs1_i,    // first operand
  input  logic                   [DATA_WIDTH-1:0] rs2_i,    // first operand

  // Output intreface
  output logic                  valid_o,
  input  logic                  ready_i,
  output tag_t                  tag_o,    // operation tag
  output logic [DATA_WIDTH-1:0] rd_o      // result
);
  import dummy_pkg::*;

  // INTERNAL SIGNALS
  // ----------------
  // Result
  logic     [DATA_WIDTH-1:0] res_d;

  // CU signals
  logic                      comb_mode;
  res_sel_t                  res_sel;

  // Iteration counter
  logic                      iter_reg_en;
  logic     [DATA_WIDTH-1:0] iter_res_q;
  tag_t                      iter_tag_q;
  logic                      iter_cnt_en;
  logic                      iter_cnt_clr;
  logic                      iter_cnt_tc;
  logic     [  IterCntW-1:0] iter_cnt_q;
  logic [IterCntW-1:0] iter_thr_d, iter_thr_q;

  // Pipeline
  logic [      PipeIdxW-1:0] pipe_idx;
  logic                      pipe_en;
  logic                      pipe_valid_q   [MAX_PIPE_DEPTH+1];
  logic [MAX_PIPE_DEPTH-1:0] pipe_valid_a;
  logic [    DATA_WIDTH-1:0] pipe_data_q    [MAX_PIPE_DEPTH+1];
  tag_t                      pipe_tag_q     [MAX_PIPE_DEPTH+1];
  logic                      pipe_valid;
  logic [    DATA_WIDTH-1:0] pipe_data;
  tag_t                      pipe_tag;
  logic [MAX_PIPE_DEPTH-1:0] pipe_busy_mask;
  logic                      pipe_busy;

  // -------------
  // SCONTROL UNIT
  // -------------
  dummy_cu u_dummy_cu (
    .clk_i        (clk_i),
    .rst_ni       (rst_ni),
    .flush_i      (flush_i),
    .valid_i      (valid_i),
    .ready_o      (ready_o),
    .ctl_i        (ctl_i),
    .valid_o      (valid_o),
    .ready_i      (ready_i),
    .comb_mode_i  (comb_mode),
    .iter_tc_i    (iter_cnt_tc),
    .pipe_busy_i  (pipe_busy),
    .pipe_valid_i (pipe_valid),
    .iter_reg_en_o(iter_reg_en),
    .iter_cnt_en_o(iter_cnt_en),
    .iter_cnt_clr_o(iter_cnt_clr),
    .pipe_en_o    (pipe_en),
    .res_sel_o    (res_sel)
  );

  // Status signals
  assign comb_mode = rs2_i == '0;  // zero-latency and no pipeline registers

  // ------
  // RESULT
  // ------
  // Waste power
  assign res_d     = rs1_i + rs2_i;

  // ------------------
  // ITERATIVE DATAPATH
  // ------------------
  // Data register
  always_ff @(posedge clk_i or negedge rst_ni) begin : iter_reg
    if (!rst_ni) begin
      iter_res_q <= 0;
      iter_tag_q <= 0;
    end else if (flush_i) begin
      iter_res_q <= 0;
      iter_tag_q <= 0;
    end else if (iter_reg_en) begin
      iter_res_q <= res_d;
      iter_tag_q <= tag_i;
    end
  end

  // Iteration counter
  always_ff @(posedge clk_i or negedge rst_ni) begin : iter_cnt
    if (!rst_ni) iter_cnt_q <= 0;
    else if (flush_i || iter_cnt_clr) iter_cnt_q <= 0;
    else if (iter_cnt_en) iter_cnt_q <= iter_cnt_q + 1;
  end
  assign iter_cnt_tc = iter_cnt_q == iter_thr_q;

  // Threshold register
  // NOTE: yes, there is a subtractor below, but we're not playing doing
  // serious stuff here, so we can live with it.
  assign iter_thr_d  = rs2_i[IterCntW-1:0];
  always_ff @(posedge clk_i or negedge rst_ni) begin : iter_thr_reg
    if (!rst_ni) iter_thr_q <= 0;
    else if (flush_i) iter_thr_q <= 0;
    else if (iter_reg_en) iter_thr_q <= iter_thr_d;
  end

  // ------------------
  // PIPELINED DATAPATH
  // ------------------
  // Pipeline index
  assign pipe_idx        = rs2_i[PipeIdxW-1:0];

  // Pipeline
  assign pipe_valid_q[0] = valid_i;
  assign pipe_data_q[0]  = res_d;
  assign pipe_tag_q[0]   = tag_i;
  generate
    for (genvar i = 1; i <= MAX_PIPE_DEPTH; i++) begin : gen_pipe_regs
      always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
          pipe_valid_q[i] <= 0;
          pipe_data_q[i]  <= 0;
          pipe_tag_q[i]   <= 0;
        end else if (flush_i) begin
          pipe_valid_q[i] <= 0;
          pipe_data_q[i]  <= 0;
          pipe_tag_q[i]   <= 0;
        end else if (pipe_en) begin
          pipe_valid_q[i] <= pipe_valid_q[i-1];
          pipe_data_q[i]  <= pipe_data_q[i-1];
          pipe_tag_q[i]   <= pipe_tag_q[i-1];
        end
      end
    end
  endgenerate

  // Pipeline output signals
  assign pipe_valid = pipe_valid_q[pipe_idx];
  assign pipe_data  = pipe_data_q[pipe_idx];
  assign pipe_tag   = pipe_tag_q[pipe_idx];

  // Pipeline status signals
  always_comb begin : pipe_busy_mask_gen
    for (int unsigned i = 0; i < MAX_PIPE_DEPTH; i++) begin
      pipe_busy_mask[i] = (i < pipe_idx) ? 1 : 0;
    end
  end
  generate
    for (genvar i = 0; i < MAX_PIPE_DEPTH; i++) begin : gen_pipe_valid
      assign pipe_valid_a[i] = pipe_valid_q[i+1];
    end
  endgenerate
  assign pipe_busy = |(pipe_busy_mask & pipe_valid_a[MAX_PIPE_DEPTH-1:0]);

  // -------------------
  // RESULT MULTIPLEXING
  // -------------------
  always_comb begin : res_mux
    case (res_sel)
      RES_SEL_PIPE: begin
        tag_o = pipe_tag;
        rd_o  = pipe_data;
      end
      RES_SEL_ITER: begin
        tag_o = iter_tag_q;
        rd_o  = iter_res_q;
      end
      default: begin  // RES_SEL_COMB
        tag_o = tag_i;
        rd_o  = res_d;
      end
    endcase
  end
endmodule
