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
// File: tb_top.hh
// Author: Michele Caon
// Date: 21/05/2024
// Description: Testbench for the dummy coprocessor

#ifndef TB_TOP_HH_
#define TB_TOP_HH_

#include <verilated.h>
#include "Vdummy_top.h"

// Coprocessor mode
enum mode_e {
    MODE_ITER,
    MODE_PIPE
};

// Request transaction
class ReqTx {
    public:
        vluint8_t  flush;
        vluint8_t  valid;
        vluint8_t  ready;
        vluint8_t  ctl;
        vluint8_t  tag;
        vluint32_t rs1;
        vluint32_t rs2;

    ReqTx();
    ~ReqTx();
};

// Response transaction
class RespTx {
    public:
        vluint8_t  valid;
        vluint8_t  ready;
        vluint8_t  tag;
        vluint32_t rd;

    RespTx();
    ~RespTx();
};

class Drv {
    private:
        Vdummy_top* dut;
    
    public:
        Drv(Vdummy_top* dut);
        ~Drv();
        
        void drive(ReqTx* req);
};

class Mon {
    private:
        Vdummy_top* dut;
    
    public:
        Mon(Vdummy_top* dut);
        ~Mon();
        
        void monitor(RespTx* resp);
        bool accepted();
};

#endif /* TB_TOP_HH_ */
