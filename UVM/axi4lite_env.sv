`timescale 1ns/1ps
package axi4lite_env_pkg;
    import uvm_pkg::*;
    import axi4lite_agent_pkg::*;
    import axi4lite_scoreboard_pkg::*;
    import axi4lite_coverage_pkg::*;
    `include "uvm_macros.svh"

    class axi4lite_env extends uvm_env;
        `uvm_component_utils(axi4lite_env)

        axi4lite_agent      agt;
        axi4lite_scoreboard sb;
        axi4lite_coverage   cov;             // coverage lives in the env, same as the scoreboard -
                                          // it just consumes monitor transactions instead of checking them

        function new(string name = "axi4lite_env", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            agt = axi4lite_agent::type_id::create("agt", this);
            sb  = axi4lite_scoreboard::type_id::create("sb", this);
            cov = axi4lite_coverage::type_id::create("cov", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            agt.agt_ap.connect(sb.sb_export);
            agt.agt_ap.connect(cov.analysis_export);
        endfunction

    endclass
endpackage
