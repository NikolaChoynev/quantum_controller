`ifndef QC_DRIVER_SV
`define QC_DRIVER_SV

class qc_driver extends uvm_driver #(qc_sequence_item);

    virtual qc_if vif;

    `uvm_component_utils(qc_driver)

    function new(string name = "qc_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db #(virtual qc_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal(get_type_name(), "Virtual interface 'vif' was not provided")
        end
    endfunction

    task run_phase(uvm_phase phase);
        qc_sequence_item item;

        initialize_bus();
        wait_for_reset_release();

        forever begin
            seq_item_port.get_next_item(item);
            drive_item(item);
            seq_item_port.item_done();
        end
    endtask

    task initialize_bus();
        vif.rst_ni                            <= 1'b0;
        vif.drv_cb.instr_i                    <= '0;
        vif.drv_cb.instr_valid_i              <= 1'b0;
        vif.drv_cb.measurement_result_valid_i <= 1'b0;
        vif.drv_cb.measurement_result_i       <= 1'b0;

        repeat (2) @(vif.drv_cb);
        vif.rst_ni <= 1'b1;
    endtask

    task wait_for_reset_release();
        do begin
            @(vif.drv_cb);
        end while (vif.rst_ni !== 1'b1);
    endtask

    task drive_item(qc_sequence_item item);
        `uvm_info(get_type_name(),
                  $sformatf("Driving item: %s", item.convert2string()),
                  UVM_MEDIUM)

        drive_instruction(item);

        if (item.send_measurement_result) begin
            drive_measurement_response(item);
        end
    endtask

    task drive_instruction(qc_sequence_item item);
        logic [INSTR_W-1:0] raw_instr;

        raw_instr = item.pack_raw();

        vif.drv_cb.instr_i       <= raw_instr;
        vif.drv_cb.instr_valid_i <= 1'b1;

        do begin
            @(vif.drv_cb);
        end while (vif.drv_cb.instr_ready_o !== 1'b1);

        vif.drv_cb.instr_valid_i <= 1'b0;
        vif.drv_cb.instr_i       <= '0;
    endtask

    task drive_measurement_response(qc_sequence_item item);
        bit request_seen;

        wait_for_measurement_request(item, request_seen);

        if (!request_seen) begin
            return;
        end

        repeat (item.measurement_latency_cycles) begin
            @(vif.drv_cb);
        end

        vif.drv_cb.measurement_result_i       <= item.measurement_result_value;
        vif.drv_cb.measurement_result_valid_i <= 1'b1;

        @(vif.drv_cb);

        vif.drv_cb.measurement_result_valid_i <= 1'b0;
        vif.drv_cb.measurement_result_i       <= 1'b0;
    endtask

    task wait_for_measurement_request(qc_sequence_item item, output bit request_seen);
        int unsigned wait_cycles;

        wait_cycles = 0;
        request_seen = 1'b0;

        do begin
            @(vif.drv_cb);
            wait_cycles++;

            if (wait_cycles > 256) begin
                `uvm_error(get_type_name(),
                           $sformatf("Timed out waiting for measurement request for q%0d",
                                     item.target_qubit))
                return;
            end
        end while (vif.drv_cb.measure_request_valid_o !== 1'b1);

        request_seen = 1'b1;

        if (vif.drv_cb.measure_qubit_o !== item.target_qubit) begin
            `uvm_warning(get_type_name(),
                         $sformatf("Measurement request qubit mismatch: expected q%0d, observed q%0d",
                                   item.target_qubit,
                                   vif.drv_cb.measure_qubit_o))
        end
    endtask

endclass : qc_driver

`endif
