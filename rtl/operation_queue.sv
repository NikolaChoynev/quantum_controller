`timescale 1ns/1ps

import qc_pkg::*;

module operation_queue #(
    parameter int DEPTH = 4
) (
    input  logic              clk_i,
    input  logic              rst_ni,

    input  logic              push_i,
    input  qc_instr_fields_t  instr_i,
    output logic              full_o,

    input  logic              flush_i,

    input  logic              pop_i,
    output qc_instr_fields_t  instr_o,
    output logic              empty_o,

    output logic [$clog2(DEPTH+1)-1:0] count_o
);

    localparam int PTR_W = (DEPTH <= 1) ? 1 : $clog2(DEPTH);
    localparam int CNT_W = $clog2(DEPTH + 1);

    localparam logic [CNT_W-1:0] DEPTH_COUNT = CNT_W'(DEPTH);

    qc_instr_fields_t mem_q [DEPTH];

    logic [PTR_W-1:0] wr_ptr_q;
    logic [PTR_W-1:0] rd_ptr_q;
    logic [CNT_W-1:0] count_q;

    logic push_en;
    logic pop_en;

    assign full_o  = (count_q == DEPTH_COUNT);
    assign empty_o = (count_q == '0);
    assign count_o = count_q;

    assign push_en = push_i && !full_o;
    assign pop_en  = pop_i  && !empty_o;

    assign instr_o = mem_q[rd_ptr_q];

    function automatic logic [PTR_W-1:0] ptr_next(input logic [PTR_W-1:0] ptr);
        if (ptr == PTR_W'(DEPTH - 1)) begin
            ptr_next = '0;
        end else begin
            ptr_next = ptr + PTR_W'(1);
        end
    endfunction

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            wr_ptr_q <= '0;
            rd_ptr_q <= '0;
            count_q  <= '0;

            for (int i = 0; i < DEPTH; i++) begin
                mem_q[i] <= '0;
            end
        end else if (flush_i) begin
            wr_ptr_q <= '0;
            rd_ptr_q <= '0;
            count_q  <= '0;

            for (int i = 0; i < DEPTH; i++) begin
                mem_q[i] <= '0;
            end
        end else begin
            if (push_en) begin
                mem_q[wr_ptr_q] <= instr_i;
                wr_ptr_q        <= ptr_next(wr_ptr_q);
            end

            if (pop_en) begin
                rd_ptr_q <= ptr_next(rd_ptr_q);
            end

            unique case ({push_en, pop_en})
                2'b10: count_q <= count_q + CNT_W'(1);
                2'b01: count_q <= count_q - CNT_W'(1);
                default: count_q <= count_q;
            endcase
        end
    end

endmodule
