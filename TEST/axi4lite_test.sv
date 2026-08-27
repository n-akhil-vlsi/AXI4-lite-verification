`timescale 1ns/1ps
package axi4lite_test_pkg;
    import uvm_pkg::*;
    import axi4lite_env_pkg::*;                  // env, config_obj are children of the test
    import axi4lite_sequence_pkg::*;
    import axi4lite_config_obj_pkg::*;
    `include "uvm_macros.svh"
 
    class axi4lite_base_test extends uvm_test;
        `uvm_component_utils(axi4lite_base_test)
 
        axi4lite_env        env;
        axi4lite_config_obj cfg;
 
        function new(string name = "axi4lite_base_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction
 
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
 
            env = axi4lite_env::type_id::create("env", this);
            cfg = axi4lite_config_obj::type_id::create("cfg");
 
            if (!uvm_config_db#(virtual axi4lite_if)::get(this, "", "AXIL_IF", cfg.axi4lite_vif))
                `uvm_fatal("build_phase", "test could not get the virtual interface from config db")
 
            uvm_config_db#(axi4lite_config_obj)::set(this, "*", "CFG", cfg);
            // 'this' is used for components; 'null' is used for non-components like tb_top module
        endfunction
 
        // shared power-on reset, issued once at the start of every derived
        // test's run_phase so the DUT/interface never sit at X before the
        // real stimulus begins.
        task do_initial_reset();
            axi4lite_reset_sequence rst_seq;
            rst_seq = axi4lite_reset_sequence::type_id::create("rst_seq");
            `uvm_info("run_phase", "issuing initial reset", UVM_NONE)
            rst_seq.start(env.agt.sqr);
        endtask
 
    endclass
 
    class axi4lite_reset_test extends axi4lite_base_test;
        `uvm_component_utils(axi4lite_reset_test)
        axi4lite_reset_sequence seq;
 
        function new(string name = "axi4lite_reset_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction
 
        task run_phase(uvm_phase phase);
            phase.raise_objection(this);
            seq = axi4lite_reset_sequence::type_id::create("seq");
            `uvm_info("run_phase", "reset test started", UVM_NONE)
            seq.start(env.agt.sqr);
            `uvm_info("run_phase", "reset test ended", UVM_NONE)
            phase.drop_objection(this);
        endtask
    endclass
 
    class axi4lite_write_only_test extends axi4lite_base_test;
        `uvm_component_utils(axi4lite_write_only_test)
        axi4lite_write_only_sequence seq;
 
        function new(string name = "axi4lite_write_only_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction
 
        task run_phase(uvm_phase phase);
            phase.raise_objection(this);
            do_initial_reset();
            seq = axi4lite_write_only_sequence::type_id::create("seq");
            `uvm_info("run_phase", "write only test started", UVM_NONE)
            seq.start(env.agt.sqr);
            `uvm_info("run_phase", "write only test ended", UVM_NONE)
            phase.drop_objection(this);
        endtask
    endclass
 
    class axi4lite_read_only_test extends axi4lite_base_test;
        `uvm_component_utils(axi4lite_read_only_test)
        axi4lite_read_only_sequence seq;
 
        function new(string name = "axi4lite_read_only_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction
 
        task run_phase(uvm_phase phase);
            phase.raise_objection(this);
            do_initial_reset();
            seq = axi4lite_read_only_sequence::type_id::create("seq");
            `uvm_info("run_phase", "read only test started", UVM_NONE)
            seq.start(env.agt.sqr);
            `uvm_info("run_phase", "read only test ended", UVM_NONE)
            phase.drop_objection(this);
        endtask
    endclass
 
    class axi4lite_write_read_together_test extends axi4lite_base_test;
        `uvm_component_utils(axi4lite_write_read_together_test)
        axi4lite_write_read_together_sequence seq;
 
        function new(string name = "axi4lite_write_read_together_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction
 
        task run_phase(uvm_phase phase);
            phase.raise_objection(this);
            do_initial_reset();
            seq = axi4lite_write_read_together_sequence::type_id::create("seq");
            `uvm_info("run_phase", "write+read together test started", UVM_NONE)
            seq.start(env.agt.sqr);
            repeat (20) @(posedge cfg.axi4lite_vif.aclk);   // let the last few transactions settle
            `uvm_info("run_phase", "write+read together test ended", UVM_NONE)
            phase.drop_objection(this);
        endtask
    endclass
 
    class axi4lite_back_to_back_test extends axi4lite_base_test;
        `uvm_component_utils(axi4lite_back_to_back_test)
        axi4lite_back_to_back_sequence seq;
 
        function new(string name = "axi4lite_back_to_back_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction
 
        task run_phase(uvm_phase phase);
            phase.raise_objection(this);
            do_initial_reset();
            seq = axi4lite_back_to_back_sequence::type_id::create("seq");
            `uvm_info("run_phase", "back to back skewed test started", UVM_NONE)
            seq.start(env.agt.sqr);
            repeat (20) @(posedge cfg.axi4lite_vif.aclk);
            `uvm_info("run_phase", "back to back skewed test ended", UVM_NONE)
            phase.drop_objection(this);
        endtask
    endclass
 
    class axi4lite_misaligned_addr_test extends axi4lite_base_test;
        `uvm_component_utils(axi4lite_misaligned_addr_test)
        axi4lite_misaligned_addr_sequence seq;
 
        function new(string name = "axi4lite_misaligned_addr_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction
 
        task run_phase(uvm_phase phase);
            phase.raise_objection(this);
            do_initial_reset();
            seq = axi4lite_misaligned_addr_sequence::type_id::create("seq");
            `uvm_info("run_phase", "misaligned address test started", UVM_NONE)
            seq.start(env.agt.sqr);
            `uvm_info("run_phase", "misaligned address test ended", UVM_NONE)
            phase.drop_objection(this);
        endtask
    endclass
 
    class axi4lite_out_of_range_test extends axi4lite_base_test;
        `uvm_component_utils(axi4lite_out_of_range_test)
        axi4lite_out_of_range_sequence seq;
 
        function new(string name = "axi4lite_out_of_range_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction
 
        task run_phase(uvm_phase phase);
            phase.raise_objection(this);
            do_initial_reset();
            seq = axi4lite_out_of_range_sequence::type_id::create("seq");
            `uvm_info("run_phase", "out of range address test started", UVM_NONE)
            seq.start(env.agt.sqr);
            `uvm_info("run_phase", "out of range address test ended", UVM_NONE)
            phase.drop_objection(this);
        endtask
    endclass
 
    class axi4lite_wstrb_test extends axi4lite_base_test;
        `uvm_component_utils(axi4lite_wstrb_test)
        axi4lite_wstrb_sequence seq;
 
        function new(string name = "axi4lite_wstrb_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction
 
        task run_phase(uvm_phase phase);
            phase.raise_objection(this);
            do_initial_reset();
            seq = axi4lite_wstrb_sequence::type_id::create("seq");
            `uvm_info("run_phase", "wstrb sweep test started", UVM_NONE)
            seq.start(env.agt.sqr);
            `uvm_info("run_phase", "wstrb sweep test ended", UVM_NONE)
            phase.drop_objection(this);
        endtask
    endclass
 
    class axi4lite_stall_test extends axi4lite_base_test;
        `uvm_component_utils(axi4lite_stall_test)
        axi4lite_stall_sequence seq;
 
        function new(string name = "axi4lite_stall_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction
 
        task run_phase(uvm_phase phase);
            phase.raise_objection(this);
            do_initial_reset();
            seq = axi4lite_stall_sequence::type_id::create("seq");
            `uvm_info("run_phase", "valid/ready stall test started", UVM_NONE)
            seq.start(env.agt.sqr);
            `uvm_info("run_phase", "valid/ready stall test ended", UVM_NONE)
            phase.drop_objection(this);
        endtask
    endclass
 
    class axi4lite_response_backpressure_test extends axi4lite_base_test;
        `uvm_component_utils(axi4lite_response_backpressure_test)
        axi4lite_response_backpressure_sequence seq;
 
        function new(string name = "axi4lite_response_backpressure_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction
 
        task run_phase(uvm_phase phase);
            phase.raise_objection(this);
            do_initial_reset();
            seq = axi4lite_response_backpressure_sequence::type_id::create("seq");
            `uvm_info("run_phase", "response backpressure test started", UVM_NONE)
            seq.start(env.agt.sqr);
            repeat (20) @(posedge cfg.axi4lite_vif.aclk);   // let the long-held responses fully settle
            `uvm_info("run_phase", "response backpressure test ended", UVM_NONE)
            phase.drop_objection(this);
        endtask
    endclass
 
    class axi4lite_random_test extends axi4lite_base_test;
        `uvm_component_utils(axi4lite_random_test)
        axi4lite_random_sequence seq;
 
        function new(string name = "axi4lite_random_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction
 
        task run_phase(uvm_phase phase);
            phase.raise_objection(this);
            do_initial_reset();
            seq = axi4lite_random_sequence::type_id::create("seq");
            `uvm_info("run_phase", "random stress test started", UVM_NONE)
            seq.start(env.agt.sqr);
            `uvm_info("run_phase", "random stress test ended", UVM_NONE)
            phase.drop_objection(this);
        endtask
    endclass
 
    // runs the master sequence, covering every scenario in one shot
    class axi4lite_all_scenarios_test extends axi4lite_base_test;
        `uvm_component_utils(axi4lite_all_scenarios_test)
        axi4lite_all_scenarios_sequence seq;
 
        function new(string name = "axi4lite_all_scenarios_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction
 
        task run_phase(uvm_phase phase);
            phase.raise_objection(this);
            do_initial_reset();
            seq = axi4lite_all_scenarios_sequence::type_id::create("seq");
            `uvm_info("run_phase", "all scenarios test started", UVM_NONE)
            seq.start(env.agt.sqr);
            repeat (20) @(posedge cfg.axi4lite_vif.aclk);
            `uvm_info("run_phase", "all scenarios test ended", UVM_NONE)
            phase.drop_objection(this);
        endtask
    endclass
 
endpackage
 