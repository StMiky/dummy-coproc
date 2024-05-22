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
// File: dummy_pkg.sv
// Author: Michele Caon
// Date: 21/05/2024
// Description: Dummy coprocessor package

package dummy_pkg;
  // Coprocessor mode control
  typedef enum logic {
    MODE_PIPE,
    MODE_ITER
  } coproc_ctl_t;

  // Result selection
  typedef enum logic [1:0] {
    RES_SEL_COMB,
    RES_SEL_PIPE,
    RES_SEL_ITER
  } res_sel_t;
endpackage : dummy_pkg
