`timescale 1ns/1ps
package axi4lite_agent_pkg;
    import uvm_pkg::*;
    import axi4lite_sequencer_pkg::*;
    import axi4lite_driver_pkg::*;
    import axi4lite_monitor_pkg::*;
    import axi4lite_config_obj_pkg::*;
    import axi4lite_seq_item_pkg::*;
    `include "uvm_macros.svh"

    class axi4lite_agent extends uvm_agent;
        `uvm_component_utils(axi4lite_agent)

        axi4lite_sequencer  sqr;
        axi4lite_driver     drv;
        axi4lite_monitor    mon;
        axi4lite_config_obj cfg;

        uvm_analysis_port #(axi4lite_seq_item) agt_ap;
        // forwards monitor transactions up to the environment, so the env
        // only ever connects to the agent, never straight to the monitor

        function new(string name = "axi4lite_agent", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(axi4lite_config_obj)::get(this, "", "CFG", cfg))
                `uvm_fatal("build_phase", "agent could not get config object")

            sqr    = axi4lite_sequencer::type_id::create("sqr", this);
            drv    = axi4lite_driver::type_id::create("drv", this);
            mon    = axi4lite_monitor::type_id::create("mon", this);
            agt_ap = new("agt_ap", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            drv.vif = cfg.axi4lite_vif;
            mon.vif = cfg.axi4lite_vif;
            drv.seq_item_port.connect(sqr.seq_item_export);
            mon.mon_ap.connect(agt_ap);
        endfunction

    endclass
endpackage
