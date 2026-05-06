`timescale 1ns/1ps

import qc_pkg::*;

module dependency_tracker #(
    parameter int NUM_QUBITS = MAX_QUBITS
) (
    input  logic             instr_valid_i,
    input  qc_instr_fields_t instr_i,

    input  logic [NUM_QUBITS-1:0] qubit_busy_i,

    output logic             uses_target_o,
    output logic             uses_control_o,

    output logic [NUM_QUBITS-1:0] qubit_mask_o,

    output logic             target_busy_o,
    output logic             control_busy_o,

    output logic             dependency_hazard_o,
    output logic             independent_o
);

    always_comb begin
        uses_target_o  = 1'b0;
        uses_control_o = 1'b0;

        unique case (instr_i.opcode)
            OP_H,
            OP_X,
            OP_Z,
            OP_MEASURE,
            OP_RESET: begin
                uses_target_o  = 1'b1;
                uses_control_o = 1'b0;
            end

            OP_CNOT: begin
                uses_target_o  = 1'b1;
                uses_control_o = 1'b1;
            end

            default: begin
                uses_target_o  = 1'b0;
                uses_control_o = 1'b0;
            end
        endcase
    end

    always_comb begin
        qubit_mask_o   = '0;
        target_busy_o  = 1'b0;
        control_busy_o = 1'b0;

        if (instr_valid_i) begin
            for (int i = 0; i < NUM_QUBITS; i++) begin
                if (uses_target_o && (int'(instr_i.target_qubit) == i)) begin
                    qubit_mask_o[i]  = 1'b1;
                    target_busy_o    = qubit_busy_i[i];
                end

                if (uses_control_o && (int'(instr_i.control_qubit) == i)) begin
                    qubit_mask_o[i]  = 1'b1;
                    control_busy_o   = qubit_busy_i[i];
                end
            end
        end
    end

    assign dependency_hazard_o = instr_valid_i &&
                                 ((uses_target_o  && target_busy_o) ||
                                  (uses_control_o && control_busy_o));

    assign independent_o = instr_valid_i && !dependency_hazard_o;

endmodule
