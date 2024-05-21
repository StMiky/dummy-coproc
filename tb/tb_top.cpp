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
// File: tb_top.cpp
// Author: Michele Caon
// Date: 21/05/2024
// Description: Testbench for the dummy coprocessor

#include <cstdlib>
#include <cstdio>
#include <random>
#include <ctime>
#include <verilated.h>
#include <verilated_fst_c.h>

#include "tb_components.hh"
#include "Vdummy_top.h"

#define END_OF_RESET_TIME 4
#define MAX_SIM_TIME 1e2
#define FST_FILENAME "logs/waves.fst"

// Clock and reset generation
void clkGen(Vdummy_top* dut);
void rstGen(Vdummy_top* dut, VerilatedContext* cntx);

// Generate request transaction
ReqTx *genReqTx(vluint8_t mode, vluint32_t rs2);

int main(int argc, char const *argv[])
{
    // Create log directory
    Verilated::mkdir("logs");

    // Create simulation context and enable tracing
    VerilatedContext* cntx = new VerilatedContext;
    cntx->commandArgs(argc, argv);
    cntx->traceEverOn(true);

    // Instantiate the DUT
    Vdummy_top* dut = new Vdummy_top(cntx);

    // Waveforms
    VerilatedFstC* m_trace = new VerilatedFstC;
    dut->trace(m_trace, 99);
    m_trace->open(FST_FILENAME);

    // TB components
    Drv *drv = new Drv(dut);
    Mon *mon = new Mon(dut);

    // Transactions
    ReqTx *req = NULL;
    RespTx *resp = new RespTx;

    // Initialize PRGs
    unsigned long prg_seed = time(NULL);
    srand(prg_seed);
    cntx->randSeed(prg_seed);

    // Request status
    bool req_accepted = true; // for first iteration

    // Test sequence
    printf("Starting simulation\n");
    while (!cntx->gotFinish() && cntx->time() < MAX_SIM_TIME)
    {
        // Generate clock and reset
        clkGen(dut);
        rstGen(dut, cntx);

        // Evaluate the DUT
        dut->eval();

        if (dut->clk_i == 1 && cntx->time() > END_OF_RESET_TIME)
        {
            // Generate transaction
            req = genReqTx(rand() & 0x1, 3);

            // Pass transaction to driver
            drv->drive(req);

            // Evaluate the DUT
            dut->eval();

            // Monitor the response
            mon->monitor(resp);
            req_accepted = mon->accepted();
        }

        // Dump waveforms and advance time
        m_trace->dump(cntx->time());
        cntx->timeInc(1);
    }

    // Complete simulation
    dut->final();
    printf("Simulation complete\n");
    m_trace->close();
    delete m_trace;
    delete dut;
    delete cntx;

    return 0;
}

void clkGen(Vdummy_top* dut)
{
    dut->clk_i ^= 1;
}

void rstGen(Vdummy_top* dut, VerilatedContext* cntx)
{
    dut->rst_ni = 1;
    if (cntx->time() < END_OF_RESET_TIME)
    {
        dut->rst_ni = 0;
        dut->flush_i = 0;
        dut->valid_i = 0;
        dut->ctl_i = 0;
        dut->tag_i = 0;
        dut->rs1_i = 0;
        dut->rs2_i = 0;
        dut->ready_i = 0;
    }
}

ReqTx *genReqTx(vluint8_t mode, vluint32_t rs2)
{
    ReqTx *req = new ReqTx;
    req->flush = 0;
    req->valid = rand() % 100 > 80;
    req->ready = rand() % 100 > 0; // most times ready to accept result
    req->ctl = mode;
    req->tag = vl_rand64() & 0x01; // randomize tag
    req->rs1 = vl_rand64() & 0xFFFFFFFF; // randomize first operand
    req->rs2 = rs2;

    return req;
}
