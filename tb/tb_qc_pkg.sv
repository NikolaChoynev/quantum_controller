`timescale 1ns/1ps

import qc_pkg::*;

module tb_qc_pkg;

    qc_instr_t instr;

    initial begin
        instr.raw = '0;

        instr.fields.opcode        = OP_H;
        instr.fields.target_qubit  = 4'd0;
        instr.fields.control_qubit = 4'd0;
        instr.fields.duration      = 12'd4;
        instr.fields.flags         = 4'b1000;
        instr.fields.reserved      = 4'd0;

        $display("Instruction raw      = 0x%08h", instr.raw);
        $display("Opcode               = 0x%0h", instr.fields.opcode);
        $display("Target qubit         = %0d", instr.fields.target_qubit);
        $display("Control qubit        = %0d", instr.fields.control_qubit);
        $display("Duration             = %0d", instr.fields.duration);
        $display("Flags                = 0b%04b", instr.fields.flags);

        if (instr.fields.opcode != OP_H) begin
            $error("Opcode mismatch");
        end

        if (instr.fields.target_qubit != 4'd0) begin
            $error("Target qubit mismatch");
        end

        $display("qc_pkg test PASSED");
        $finish;
    end

endmodule
