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
// File: dummy_cu.sv
// Author: Michele Caon
// Date: 21/05/2024
// Description: Dummy coprocessor control unit

module dummy_cu (
  input logic clk_i,
  input logic rst_ni,
  input logic flush_i,

  // CPU interface
  input  logic                   valid_i,
  output logic                   ready_o,
  input  dummy_pkg::coproc_ctl_t ctl_i,    // coprocessor mode control
  output logic                   valid_o,
  input  logic                   ready_i,

  // Datapath interface
  input  logic                comb_mode_i,    // combinational mode
  input  logic                iter_tc_i,      // iteration terminal count
  input  logic                pipe_busy_i,    // pipeline busy
  input  logic                pipe_valid_i,   // valid from pipeline
  output logic                iter_reg_en_o,  // iterative unit register enable
  output logic                iter_cnt_en_o,  // iterative unit counter enable
  output logic                iter_cnt_clr_o, // iterative unit counter clear
  output logic                pipe_en_o,      // pipeline enable
  output dummy_pkg::res_sel_t res_sel_o       // result selection
);
  import dummy_pkg::*;

  // INTERNAL SIGNALS
  // ----------------
  // FSM states
  typedef enum logic [2:0] {
    RESET,
    IDLE,
    IDLE_PIPE,
    WAIT_ITER,
    WAIT_CORE
  } fsm_state_t;
  fsm_state_t curr_state, next_state;

  // --------------------
  // FINITE STATE MACHINE
  // --------------------
  // State transition
  always_comb begin : fsm_state_prog
    unique case (curr_state)
      RESET:   next_state = IDLE;
      IDLE: begin
        if (comb_mode_i) next_state = IDLE;  // just forward handshaking
        else begin
          unique case (ctl_i)
            MODE_PIPE: begin
              if (valid_i) next_state = IDLE_PIPE;
              else next_state = IDLE;
            end
            default: begin  // MODE_ITER
              if (valid_i) next_state = WAIT_ITER;
              else next_state = IDLE;
            end
          endcase
        end
      end
      IDLE_PIPE: begin
        // Exit pipeline mode if the pipeline is empty
        if (!pipe_busy_i && !pipe_valid_i) next_state = IDLE;
        else next_state = IDLE_PIPE;
      end
      WAIT_ITER: begin
        // Exit if the output transaction takes place
        if (iter_tc_i) begin
          if (ready_i) next_state = IDLE;
          else next_state = WAIT_CORE;
        end else next_state = WAIT_ITER;
      end
      WAIT_CORE: begin
        // Exit when downstream is ready
        if (ready_i) next_state = IDLE;
        else next_state = WAIT_CORE;
      end
      default: next_state = RESET;
    endcase
  end

  // Output network (Mealy)
  always_comb begin : fsm_out_net
    // Default values
    valid_o       = 1'b0;
    ready_o       = 1'b0;
    iter_reg_en_o = 1'b0;
    iter_cnt_en_o = 1'b0;
    iter_cnt_clr_o = 1'b0;
    pipe_en_o     = 1'b0;
    res_sel_o     = RES_SEL_COMB;

    unique case (curr_state)
      IDLE: begin
        res_sel_o = RES_SEL_COMB;
        if (comb_mode_i) begin
          // Forward handshaking in combinational mode
          valid_o = valid_i;
          ready_o = ready_i;
        end else begin
          // Pipeline and sequential units are empty here
          valid_o = 1'b0;
          ready_o = 1'b1;
          unique case (ctl_i)
            MODE_PIPE: pipe_en_o = valid_i;
            default: begin  // MODE_ITER
              iter_reg_en_o = valid_i;
              iter_cnt_en_o = valid_i;
            end
          endcase
        end
      end
      IDLE_PIPE: begin
        valid_o   = pipe_valid_i;
        pipe_en_o = ready_i;  // keep advancing if downstream is ready
        res_sel_o = RES_SEL_PIPE;
        // Only accept pipeline requests
        unique case (ctl_i)
          MODE_PIPE: ready_o = ready_i;
          default:   ready_o = 1'b0;  // MODE_ITER
        endcase
      end
      WAIT_ITER: begin
        valid_o       = iter_tc_i;
        ready_o       = 1'b0;
        iter_cnt_en_o = 1'b1;
        iter_cnt_clr_o = iter_tc_i & ready_i;
        res_sel_o     = RES_SEL_ITER;
      end
      WAIT_CORE: begin
        valid_o        = 1'b1;
        ready_o        = 1'b0;
        iter_cnt_clr_o = ready_i;
        res_sel_o      = RES_SEL_ITER;
      end
      default: ;  // use default values
    endcase
  end

  // State update
  always_ff @(posedge clk_i or negedge rst_ni) begin : fsm_state_upd
    if (!rst_ni) curr_state <= RESET;
    else if (flush_i) curr_state <= RESET;
    else curr_state <= next_state;
  end
endmodule
