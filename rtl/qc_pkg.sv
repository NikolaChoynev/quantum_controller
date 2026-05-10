`timescale 1ns/1ps

package qc_pkg;

    // ============================================================
    // Quantum Controller Package
    // ------------------------------------------------------------
    // This package defines the basic architectural parameters,
    // opcode encoding and instruction format used by the
    // instruction-driven RTL quantum controller.
    // ============================================================

    // ------------------------------------------------------------
    // Global architectural parameters
    // ------------------------------------------------------------
    parameter int INSTR_W      = 32;
    parameter int OPCODE_W     = 4;
    parameter int QUBIT_ID_W   = 4;
    parameter int DURATION_W   = 12;
    parameter int FLAGS_W      = 4;
    parameter int RESERVED_W   = 4;

    parameter int MAX_QUBITS   = 16;

    // ------------------------------------------------------------
    // Opcode encoding
    // ------------------------------------------------------------
    typedef enum logic [OPCODE_W-1:0] {
        OP_NOP     = 4'h0,
        OP_H       = 4'h1,
        OP_X       = 4'h2,
        OP_Z       = 4'h3,
        OP_CNOT    = 4'h4,
        OP_MEASURE = 4'h5,
        OP_WAIT    = 4'h6,
        OP_RESET   = 4'h7,
        OP_BRANCH  = 4'h8,
        OP_INVALID = 4'hF
    } qc_opcode_e;

    // ------------------------------------------------------------
    // Instruction flags
    // ------------------------------------------------------------
    localparam int FLAG_VALID_BIT       = 3;
    localparam int FLAG_CONDITIONAL_BIT = 2;
    localparam int FLAG_FEEDBACK_BIT    = 1;
    localparam int FLAG_EXPECTED_BIT    = 0;

    typedef struct packed {
        logic valid;
        logic conditional;
        logic feedback;
        logic expected;
    } qc_flags_t;

    // ------------------------------------------------------------
    // Decoded instruction field representation
    //
    // 32-bit instruction format:
    //
    // [31:28] opcode
    // [27:24] target_qubit
    // [23:20] control_qubit
    // [19:8]  duration
    // [7:4]   flags
    // [3:0]   reserved
    // ------------------------------------------------------------
    typedef struct packed {
        qc_opcode_e                 opcode;
        logic [QUBIT_ID_W-1:0]      target_qubit;
        logic [QUBIT_ID_W-1:0]      control_qubit;
        logic [DURATION_W-1:0]      duration;
        logic [FLAGS_W-1:0]         flags;
        logic [RESERVED_W-1:0]      reserved;
    } qc_instr_fields_t;

    // ------------------------------------------------------------
    // Union representation:
    // Allows the same instruction to be used either as raw 32-bit
    // data or as decoded fields.
    // ------------------------------------------------------------
    typedef union packed {
        logic [INSTR_W-1:0]         raw;
        qc_instr_fields_t           fields;
    } qc_instr_t;

endpackage
