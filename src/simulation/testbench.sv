`include "uvm_macros.svh"
import uvm_pkg::*;

class ps2_item extends uvm_sequence_item;

    rand bit ps2_kbclk;
    rand bit ps2_kbdat;
    bit [15:0] hex;

    function new(string name = "ps2_item");
        super.new(name);
    endfunction

    `uvm_object_utils_begin(ps2_item)
        `uvm_field_int(ps2_kbclk, UVM_DEFAULT)
        `uvm_field_int(ps2_kbdat, UVM_DEFAULT) 
        `uvm_field_int(hex, UVM_DEFAULT)
    `uvm_object_utils_end  

    virtual function string my_print();
		return $sformatf(
			"PS2_KBCLK = %1b PS2_KBDAT = %1b hex = %4h",
			ps2_kbclk, ps2_kbdat, hex
		);
	endfunction

endclass

class generator extends uvm_sequence;

    `uvm_object_utils(generator)

    function  new(string name = "generator");
        super.new(name);   
    endfunction

    int num = 500;

    virtual task body();

        for (int i = 0; i < num; i++) begin
            
            ps2_item item = ps2_item::type_id::create("item");
            start_item(item);
            
            item.randomize();
            `uvm_info("Generator", $sformatf("Item %0d/%0d created", i+1, num), UVM_LOW)
            item.print();

            finish_item(item);
        end

    endtask

endclass

class driver extends uvm_driver #(ps2_item);
    
    `uvm_component_utils(driver)

    function new(string name="driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction 

    virtual ps2_if vif;

    virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if (!uvm_config_db#(virtual ps2_if)::get(this, "", "ps2_vif", vif))
			`uvm_fatal("Driver", "Could not get virtual interface.")
	endfunction

    virtual task run_phase(uvm_phase phase);
		super.run_phase(phase);
		forever begin
			ps2_item item;
			seq_item_port.get_next_item(item);
			`uvm_info("Driver", $sformatf("%s", item.my_print()), UVM_LOW)
			
            
            vif.ps2_kbclk <= item.ps2_kbclk;
			vif.ps2_kbdat <= item.ps2_kbdat;
			
			@(posedge vif.clk);
			seq_item_port.item_done();
		end
	endtask

endclass

class monitor extends uvm_monitor;

    `uvm_component_utils(monitor)

    function new(string name = "monitor", uvm_component parent = null);
		super.new(name, parent);
	endfunction
	
	virtual ps2_if vif;
	uvm_analysis_port #(ps2_item) mon_analysis_port;

    virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if (!uvm_config_db#(virtual ps2_if)::get(this, "", "ps2_vif", vif))
			`uvm_fatal("Monitor", "No interface.")
		mon_analysis_port = new("mon_analysis_port", this);
	endfunction
	
    ps2_item item;

	virtual task run_phase(uvm_phase phase);	
		super.run_phase(phase);
		@(posedge vif.clk);
		forever begin
			
            @(posedge vif.clk);
            item = new;
            item.ps2_kbclk = vif.ps2_kbclk;
            item.ps2_kbdat = vif.ps2_kbdat;
            item.hex = vif.hex;

			`uvm_info("Monitor", $sformatf("%s", item.my_print()), UVM_LOW)
			//item.print();
            mon_analysis_port.write(item);
		end
	endtask

endclass

class agent extends uvm_agent;

    `uvm_component_utils(agent)
	
	function new(string name = "agent", uvm_component parent = null);
		super.new(name, parent);
	endfunction
	
	driver d0;
	monitor m0;
	uvm_sequencer #(ps2_item) s0;

    virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		s0 = uvm_sequencer#(ps2_item)::type_id::create("s0", this);
		d0 = driver::type_id::create("d0", this);
		m0 = monitor::type_id::create("m0", this);
	endfunction

    virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		d0.seq_item_port.connect(s0.seq_item_export);
	endfunction

endclass


class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard)

	function new(string name = "scoreboard", uvm_component parent = null);
		super.new(name, parent);
	endfunction
	
	uvm_analysis_imp #(ps2_item, scoreboard) mon_analysis_imp;
	
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		mon_analysis_imp = new("mon_analysis_imp", this);
	endfunction


	//=====================================================
	// bit parity = 1'b0;

	typedef enum bit[1:0] {waiting_for_start, receiving_data, data_end} states;
	states state;
	reg[7:0] data = 8'd0;
	reg[3:0] counter = 4'd0;
	reg[63:0] code = 64'd0;
	reg[15:0] display_code = 16'd0;
	reg[2:0] byte_num = 3'd0;
	reg parity =1'b0;



reg[3:0] counter_old;
	reg[15:0] hex_check = 16'd0;

	reg ps2_clk_buffer = 1'd0;

	virtual function write(ps2_item item);
	
		if(hex_check == item.hex)begin
			`uvm_info("Scoreboard", $sformatf("PASS! expected = %16b, got = %16b", hex_check, item.hex), UVM_LOW)
		end
		else begin
			`uvm_error("Scoreboard", $sformatf("FAIL! expected = %16b, got = %16b", hex_check, item.hex))
		end

		if(ps2_clk_buffer ==1'b1 && item.ps2_kbclk ==1'b0) begin
			
			case (state)
				waiting_for_start:begin
					
					if(item.ps2_kbdat == 1'b0)begin
						counter = 4'd0;
						data = 8'd0;
						if(byte_num ===3'd0) code = 64'd0;
						state= receiving_data;
						parity =1'b0;
					end
				end
				receiving_data:begin

					// if(counter == 4'b000) parity =1'b1;
					// else parity = parity ^ item.ps2_kbdat;

					parity =parity ^ item.ps2_kbdat;

					counter_old =counter;
					if(counter ==4'b1000) state = data_end;
					else begin
						
						counter = counter + 1'b1;
						data =  data| {{item.ps2_kbdat}, {7{1'b0}}};
					end		
					if(counter_old < 4'b0111)begin
						data = data >> 1'b1;
					end		
				end

				data_end: begin
					if (item.ps2_kbdat == 1'b1) begin
                    
                    if (parity) begin               //valid parity
                        code = (code << 8) | data;
                        
                        if (data == 8'hE0 || data == 8'hF0 ||  data == 8'hE1 ||code[23:0] == 24'hE0F07C || code[15:0] == 16'hE012
                        || code[15:0] == 16'hE114 || code[23:0] == 24'hE11477 || code[47:0] == 48'hE11477E1F014) begin // treba primiti jos bajtova
                            
                            byte_num = byte_num + 3'b001;
                        end
                        else begin
                            state        = waiting_for_start;
                            hex_check = code[15:0];
                            byte_num     = 3'd0;
                        end
                        
                        
                        //E1 14 77 E1 F0 14 E0 77
                        
                    end
                    else begin                      //invalid parity
                        hex_check = 16'hEEEE;
                        
                    end
                end
                state = waiting_for_start;
				end

				
			endcase 

		end
		ps2_clk_buffer = item.ps2_kbclk;
	
	endfunction
endclass


class env extends uvm_env;
	`uvm_component_utils(env)

	function new(string name = "env", uvm_component parent = null);
		super.new(name, parent);
	endfunction
	
	agent a0;
	scoreboard sb0;

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		a0 = agent::type_id::create("a0", this);
		sb0 = scoreboard::type_id::create("sb0", this);
	endfunction
	
	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		a0.m0.mon_analysis_port.connect(sb0.mon_analysis_imp);
	endfunction

endclass

class test extends uvm_test;
	`uvm_component_utils(test)

	function new(string name = "test", uvm_component parent = null);
		super.new(name, parent);
	endfunction
	
	virtual ps2_if vif;

	env e0;
	generator g0;
	
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if (!uvm_config_db#(virtual ps2_if)::get(this, "", "ps2_vif", vif))
			`uvm_fatal("Test", "No interface.")
		e0 = env::type_id::create("e0", this);
		g0 = generator::type_id::create("g0");
	endfunction
	
	virtual function void end_of_elaboration_phase(uvm_phase phase);
		uvm_top.print_topology();
	endfunction


	virtual task run_phase(uvm_phase phase);
		phase.raise_objection(this);
		
		vif.rst_n <= 0;
		#20 vif.rst_n <= 1;
		
		g0.start(e0.a0.s0);
		phase.drop_objection(this);
	endtask


endclass


interface ps2_if( input bit clk);

	logic ps2_kbclk;
	logic ps2_kbdat;
    logic rst_n;
    logic [15:0]hex;

endinterface


module testbench;
	reg clk;

	ps2_if dut_if (.clk(clk));
	ps2 dut (.clk(clk), .PS2_KBCLK(dut_if.ps2_kbclk),
		.PS2_KBDAT(dut_if.ps2_kbdat),
		.rst_n(dut_if.rst_n),
		.hex(dut_if.hex));
	
	initial begin
		clk=0;
		forever begin 
			#5 clk=~clk;
		end
	end

	initial begin
		uvm_config_db#(virtual ps2_if)::set(null, "*", "ps2_vif", dut_if);
		run_test("test");
	end

endmodule
