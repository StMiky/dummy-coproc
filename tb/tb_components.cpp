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
// File: tb_components.cpp
// Author: Michele Caon
// Date: 21/05/2024
// Description: Testbench components for the dummy coprocessor

#include "tb_components.hh"

ReqTx::ReqTx()
{
    flush = 0;
    valid = 0;
    ready = 0;
    ctl = 0;
    tag = 0;
    rs1 = 0;
    rs2 = 0;
}

ReqTx::~ReqTx()
{
}

RespTx::RespTx()
{
    valid = 0;
    ready = 0;
    tag = 0;
    rd = 0;
}

RespTx::~RespTx()
{
}

Drv::Drv(Vdummy_top* dut)
{
    this->dut = dut;
}

void Drv::drive(ReqTx* req)
{
    // No transaction
    dut->valid_i = 0;
    dut->flush_i = 0;
    if (req == NULL) return;

    // Drive inputs
    dut->flush_i = req->flush;
    dut->valid_i = req->valid;
    dut->ready_i = req->ready;
    dut->ctl_i = req->ctl;
    dut->tag_i = req->tag;
    dut->rs1_i = req->rs1;
    dut->rs2_i = req->rs2;
}

Mon::Mon(Vdummy_top* dut)
{
    this->dut = dut;
}

Mon::~Mon()
{
}

void Mon::monitor(RespTx* resp)
{
    // Monitor outputs
    resp->valid = dut->valid_o;
    resp->ready = dut->ready_o;
    resp->tag = dut->tag_o;
    resp->rd = dut->rd_o;
}

bool Mon::accepted()
{
    return dut->valid_i && dut->ready_o;
}
