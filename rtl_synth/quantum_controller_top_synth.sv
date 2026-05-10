`timescale 1ns/1ps

module quantum_controller_top_synth #(
    parameter integer QUEUE_DEPTH = 4,
    parameter integer NUM_QUBITS  = 16
) (
    input  wire                    clk_i,
    input  wire                    rst_ni,

    input  wire [31:0]             instr_i,
    input  wire                    instr_valid_i,
    output wire                    instr_ready_o,

    input  wire                    measurement_result_valid_i,
    input  wire                    measurement_result_i,

    output reg                     issue_valid_o,
    output reg  [3:0]              issue_opcode_o,
    output reg  [3:0]              issue_target_qubit_o,
    output reg  [3:0]              issue_control_qubit_o,
    output reg  [11:0]             issue_duration_o,
    output reg  [3:0]              issue_flags_o,

    output reg                     command_valid_o,
    output reg  [3:0]              command_opcode_o,
    output reg  [3:0]              command_target_qubit_o,
    output reg  [3:0]              command_control_qubit_o,
    output reg  [11:0]             command_duration_o,
    output reg  [3:0]              command_flags_o,

    output reg                     gate_cmd_o,
    output reg                     measure_cmd_o,
    output reg                     wait_cmd_o,
    output reg                     reset_cmd_o,
    output reg                     branch_cmd_o,
    output reg                     nop_cmd_o,

    output reg                     measure_request_valid_o,
    output reg  [3:0]              measure_qubit_o,
    output wire                    measurement_busy_o,

    output reg                     measurement_result_out_valid_o,
    output reg  [3:0]              measurement_result_qubit_o,
    output reg                     measurement_result_value_o,
    output reg  [NUM_QUBITS-1:0]   measurement_valid_o,
    output reg  [NUM_QUBITS-1:0]   measurement_results_o,
    output reg                     unexpected_measurement_result_o,

    output reg                     feedback_valid_o,
    output reg                     branch_taken_o,
    output reg  [11:0]             branch_target_o,
    output reg  [3:0]              feedback_qubit_o,
    output reg                     feedback_value_o,
    output reg                     condition_checked_o,
    output reg                     missing_measurement_o,

    output wire                    scheduler_stall_o,
    output reg                     illegal_instr_o,
    output reg                     illegal_issue_o,

    output wire [2:0]              queue_count_o,
    output wire [NUM_QUBITS-1:0]   qubit_busy_o
);

    localparam [3:0] OP_NOP     = 4'h0;
    localparam [3:0] OP_H       = 4'h1;
    localparam [3:0] OP_X       = 4'h2;
    localparam [3:0] OP_Z       = 4'h3;
    localparam [3:0] OP_CNOT    = 4'h4;
    localparam [3:0] OP_MEASURE = 4'h5;
    localparam [3:0] OP_WAIT    = 4'h6;
    localparam [3:0] OP_RESET   = 4'h7;
    localparam [3:0] OP_BRANCH  = 4'h8;

    wire [3:0]  dec_opcode;
    wire [3:0]  dec_target;
    wire [3:0]  dec_control;
    wire [11:0] dec_duration;
    wire [3:0]  dec_flags;
    wire        dec_valid;
    reg         dec_illegal;

    assign dec_opcode   = instr_i[31:28];
    assign dec_target   = instr_i[27:24];
    assign dec_control  = instr_i[23:20];
    assign dec_duration = instr_i[19:8];
    assign dec_flags    = instr_i[7:4];
    assign dec_valid    = dec_flags[3];

    always @* begin
        case (dec_opcode)
            OP_NOP,
            OP_H,
            OP_X,
            OP_Z,
            OP_CNOT,
            OP_MEASURE,
            OP_WAIT,
            OP_RESET,
            OP_BRANCH: dec_illegal = 1'b0;
            default:   dec_illegal = 1'b1;
        endcase
    end

    reg [31:0] queue_mem [0:QUEUE_DEPTH-1];
    reg [1:0]  wr_ptr_q;
    reg [1:0]  rd_ptr_q;
    reg [2:0]  count_q;

    wire queue_full;
    wire queue_empty;
    wire queue_push;
    wire queue_pop;
    wire queue_flush;

    assign queue_full    = (count_q == QUEUE_DEPTH[2:0]);
    assign queue_empty   = (count_q == 3'd0);
    assign queue_flush   = feedback_valid_o && branch_taken_o;
    assign instr_ready_o = !queue_full && !queue_flush;
    assign queue_count_o = count_q;

    assign queue_push = instr_valid_i && instr_ready_o && dec_valid && !dec_illegal && !queue_flush;

    wire [31:0] queue_head;
    assign queue_head = queue_mem[rd_ptr_q];

    wire [3:0]  q_opcode;
    wire [3:0]  q_target;
    wire [3:0]  q_control;
    wire [11:0] q_duration;
    wire [3:0]  q_flags;

    assign q_opcode   = queue_head[31:28];
    assign q_target   = queue_head[27:24];
    assign q_control  = queue_head[23:20];
    assign q_duration = queue_head[19:8];
    assign q_flags    = queue_head[7:4];

    reg [11:0] busy_cnt_q [0:NUM_QUBITS-1];
    reg [11:0] wait_cnt_q;
    reg        branch_inflight_q;

    genvar gi;
    generate
        for (gi = 0; gi < NUM_QUBITS; gi = gi + 1) begin : gen_busy
            assign qubit_busy_o[gi] = (busy_cnt_q[gi] != 12'd0);
        end
    endgenerate

    reg uses_target;
    reg uses_control;

    always @* begin
        uses_target  = 1'b0;
        uses_control = 1'b0;

        case (q_opcode)
            OP_H,
            OP_X,
            OP_Z,
            OP_MEASURE,
            OP_RESET: begin
                uses_target  = 1'b1;
                uses_control = 1'b0;
            end

            OP_CNOT: begin
                uses_target  = 1'b1;
                uses_control = 1'b1;
            end

            default: begin
                uses_target  = 1'b0;
                uses_control = 1'b0;
            end
        endcase
    end

    wire target_busy;
    wire control_busy;
    wire dependency_hazard;
    wire measurement_issue_blocked;
    wire branch_issue_blocked;
    wire scheduler_issue_ready;
    wire wait_active;
    wire can_issue;

    assign target_busy       = uses_target  ? qubit_busy_o[q_target]  : 1'b0;
    assign control_busy      = uses_control ? qubit_busy_o[q_control] : 1'b0;
    assign dependency_hazard = !queue_empty && (target_busy || control_busy);
    assign measurement_issue_blocked =
        measurement_pending_q ||
        (issue_valid_o && (issue_opcode_o == OP_MEASURE)) ||
        (command_valid_o && (command_opcode_o == OP_MEASURE));
    assign branch_issue_blocked =
        branch_inflight_q ||
        (issue_valid_o && (issue_opcode_o == OP_BRANCH)) ||
        (command_valid_o && (command_opcode_o == OP_BRANCH));
    assign scheduler_issue_ready =
        !queue_flush &&
        !branch_issue_blocked &&
        !(measurement_issue_blocked &&
          !queue_empty &&
          (q_opcode == OP_MEASURE));
    assign wait_active       = (wait_cnt_q != 12'd0);
    assign can_issue         = !queue_empty &&
                               !dependency_hazard &&
                               scheduler_issue_ready &&
                               !wait_active;
    assign queue_pop         = can_issue;
    assign scheduler_stall_o = !queue_empty &&
                               (dependency_hazard ||
                                wait_active ||
                                !scheduler_issue_ready);

    wire [11:0] operation_duration;
    assign operation_duration = (q_duration == 12'd0) ? 12'd1 : q_duration;

    reg measurement_pending_q;
    reg [3:0] measurement_pending_qubit_q;

    assign measurement_busy_o = measurement_pending_q;

    integer i;

    always @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            wr_ptr_q <= 2'd0;
            rd_ptr_q <= 2'd0;
            count_q  <= 3'd0;

            issue_valid_o         <= 1'b0;
            issue_opcode_o        <= OP_NOP;
            issue_target_qubit_o  <= 4'd0;
            issue_control_qubit_o <= 4'd0;
            issue_duration_o      <= 12'd0;
            issue_flags_o         <= 4'd0;

            command_valid_o         <= 1'b0;
            command_opcode_o        <= OP_NOP;
            command_target_qubit_o  <= 4'd0;
            command_control_qubit_o <= 4'd0;
            command_duration_o      <= 12'd0;
            command_flags_o         <= 4'd0;

            gate_cmd_o    <= 1'b0;
            measure_cmd_o <= 1'b0;
            wait_cmd_o    <= 1'b0;
            reset_cmd_o   <= 1'b0;
            branch_cmd_o  <= 1'b0;
            nop_cmd_o     <= 1'b0;

            measurement_pending_q       <= 1'b0;
            measurement_pending_qubit_q <= 4'd0;
            wait_cnt_q                  <= 12'd0;
            branch_inflight_q           <= 1'b0;

            measure_request_valid_o <= 1'b0;
            measure_qubit_o         <= 4'd0;

            measurement_result_out_valid_o <= 1'b0;
            measurement_result_qubit_o     <= 4'd0;
            measurement_result_value_o     <= 1'b0;
            measurement_valid_o            <= {NUM_QUBITS{1'b0}};
            measurement_results_o          <= {NUM_QUBITS{1'b0}};
            unexpected_measurement_result_o <= 1'b0;

            feedback_valid_o      <= 1'b0;
            branch_taken_o        <= 1'b0;
            branch_target_o       <= 12'd0;
            feedback_qubit_o      <= 4'd0;
            feedback_value_o      <= 1'b0;
            condition_checked_o   <= 1'b0;
            missing_measurement_o <= 1'b0;

            illegal_instr_o <= 1'b0;
            illegal_issue_o <= 1'b0;

            for (i = 0; i < NUM_QUBITS; i = i + 1) begin
                busy_cnt_q[i] <= 12'd0;
            end
        end else begin
            issue_valid_o <= 1'b0;

            command_valid_o <= 1'b0;
            command_opcode_o <= OP_NOP;
            command_target_qubit_o <= 4'd0;
            command_control_qubit_o <= 4'd0;
            command_duration_o <= 12'd0;
            command_flags_o <= 4'd0;

            gate_cmd_o    <= 1'b0;
            measure_cmd_o <= 1'b0;
            wait_cmd_o    <= 1'b0;
            reset_cmd_o   <= 1'b0;
            branch_cmd_o  <= 1'b0;
            nop_cmd_o     <= 1'b0;

            measure_request_valid_o <= 1'b0;

            measurement_result_out_valid_o <= 1'b0;
            unexpected_measurement_result_o <= 1'b0;

            feedback_valid_o      <= 1'b0;
            branch_taken_o        <= 1'b0;
            condition_checked_o   <= 1'b0;
            missing_measurement_o <= 1'b0;

            illegal_instr_o <= 1'b0;
            illegal_issue_o <= 1'b0;

            for (i = 0; i < NUM_QUBITS; i = i + 1) begin
                if (busy_cnt_q[i] != 12'd0)
                    busy_cnt_q[i] <= busy_cnt_q[i] - 12'd1;
            end

            if (wait_cnt_q != 12'd0)
                wait_cnt_q <= wait_cnt_q - 12'd1;

            if (instr_valid_i && instr_ready_o && dec_illegal)
                illegal_instr_o <= 1'b1;

            if (feedback_valid_o)
                branch_inflight_q <= 1'b0;

            if (queue_flush) begin
                wr_ptr_q <= 2'd0;
                rd_ptr_q <= 2'd0;
                count_q  <= 3'd0;

                for (i = 0; i < QUEUE_DEPTH; i = i + 1) begin
                    queue_mem[i] <= 32'd0;
                end
            end else begin
                if (queue_push) begin
                    queue_mem[wr_ptr_q] <= instr_i;
                    wr_ptr_q <= wr_ptr_q + 2'd1;
                end

                if (can_issue) begin
                    issue_valid_o         <= 1'b1;
                    issue_opcode_o        <= q_opcode;
                    issue_target_qubit_o  <= q_target;
                    issue_control_qubit_o <= q_control;
                    issue_duration_o      <= q_duration;
                    issue_flags_o         <= q_flags;

                    command_opcode_o        <= q_opcode;
                    command_target_qubit_o  <= q_target;
                    command_control_qubit_o <= q_control;
                    command_duration_o      <= q_duration;
                    command_flags_o         <= q_flags;

                    case (q_opcode)
                        OP_NOP: begin
                            nop_cmd_o <= 1'b1;
                        end

                        OP_H,
                        OP_X,
                        OP_Z,
                        OP_CNOT: begin
                            command_valid_o <= 1'b1;
                            gate_cmd_o      <= 1'b1;
                        end

                        OP_MEASURE: begin
                            command_valid_o <= 1'b1;
                            measure_cmd_o   <= 1'b1;

                            if (!measurement_pending_q) begin
                                measurement_pending_q       <= 1'b1;
                                measurement_pending_qubit_q <= q_target;
                                measure_request_valid_o     <= 1'b1;
                                measure_qubit_o             <= q_target;
                            end
                        end

                        OP_WAIT: begin
                            command_valid_o <= 1'b1;
                            wait_cmd_o      <= 1'b1;
                            wait_cnt_q      <= operation_duration;
                        end

                        OP_RESET: begin
                            command_valid_o <= 1'b1;
                            reset_cmd_o     <= 1'b1;
                        end

                        OP_BRANCH: begin
                            command_valid_o     <= 1'b1;
                            branch_cmd_o        <= 1'b1;
                            branch_inflight_q   <= 1'b1;

                            feedback_valid_o <= 1'b1;
                            feedback_qubit_o <= q_target;
                            branch_target_o  <= q_duration;

                            if (q_flags[2] || q_flags[1]) begin
                                if (measurement_valid_o[q_target]) begin
                                    condition_checked_o <= 1'b1;
                                    feedback_value_o    <= measurement_results_o[q_target];
                                    branch_taken_o      <= (measurement_results_o[q_target] == q_flags[0]);
                                end else begin
                                    missing_measurement_o <= 1'b1;
                                    branch_taken_o        <= 1'b0;
                                end
                            end else begin
                                branch_taken_o <= 1'b1;
                            end
                        end

                        default: begin
                            illegal_issue_o <= 1'b1;
                        end
                    endcase

                    if (uses_target)
                        busy_cnt_q[q_target] <= operation_duration;

                    if (uses_control)
                        busy_cnt_q[q_control] <= operation_duration;

                    rd_ptr_q <= rd_ptr_q + 2'd1;
                end

                if (queue_push && !queue_pop)
                    count_q <= count_q + 3'd1;
                else if (!queue_push && queue_pop)
                    count_q <= count_q - 3'd1;
            end

            if (measurement_result_valid_i) begin
                if (measurement_pending_q) begin
                    measurement_pending_q <= 1'b0;

                    measurement_result_out_valid_o <= 1'b1;
                    measurement_result_qubit_o     <= measurement_pending_qubit_q;
                    measurement_result_value_o     <= measurement_result_i;

                    measurement_valid_o[measurement_pending_qubit_q]  <= 1'b1;
                    measurement_results_o[measurement_pending_qubit_q] <= measurement_result_i;
                end else begin
                    unexpected_measurement_result_o <= 1'b1;
                end
            end
        end
    end

endmodule
