module ps2(input PS2_KBCLK,
    input PS2_KBDAT,
    input clk,
    input rst_n,
    output [15:0]hex)
    ;
    
    assign hex = display_code_reg;
    
    localparam waiting_for_start = 2'b00;
    localparam receiving_data    = 2'b01;
    localparam data_end          = 2'b10;
    
    // localparam break_code = 8'hF0;
    
    localparam START = 1'b0;
    localparam STOP  = 1'b1;
    
    
    reg[1:0] state_reg, state_next = waiting_for_start;
    reg[7:0]  data_reg, data_next;
    reg parity_reg, parity_next;
    reg[2:0] counter_reg, counter_next;
    reg[63:0] code_reg, code_next;
    reg[15:0] display_code_reg, display_code_next;
    reg[2:0] byte_num_reg, byte_num_next;
    
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            //reset svih _reg
            state_reg        <= waiting_for_start;
            data_reg         <= 8'h00;
            parity_reg       <= 1'b0;
            counter_reg      <= 3'b000;
            code_reg         <= 64'h0000000000000000;
            display_code_reg <= 16'h0000;
            byte_num_reg     <= 3'b000;
            
        end
        else begin
            //_reg <= _next
            state_reg        <= state_next;
            data_reg         <= data_next;
            parity_reg       <= parity_next;
            counter_reg      <= counter_next;
            code_reg         <= code_next;
            display_code_reg <= display_code_next;
            byte_num_reg     <= byte_num_next;
        end
        
    end
    
    always @(negedge PS2_KBCLK) begin
        //_next = _reg
        state_next        = state_reg;
        data_next         = data_reg;
        parity_next       = parity_reg;
        counter_next      = counter_reg;
        code_next         = code_reg;
        display_code_next = display_code_reg;
        byte_num_next     = byte_num_reg;
        
        case (state_reg)
            waiting_for_start: begin
                if (PS2_KBDAT == START) begin
                    counter_next     = 3'b000;
                    data_next        = 8'h00;
                    if (byte_num_reg == 3'd0) code_next = 64'h0000000000000000;
                    state_next       = receiving_data;
                    
                end
                
            end
            receiving_data: begin
                
                if (counter_reg == 3'b000) parity_next                        = 1'b1;
                else                       parity_next = parity_reg ^ PS2_KBDAT;
                
                data_next = (data_reg | {PS2_KBDAT, {7{1'b0}}}) >> 1'b1;
                
                
                if (counter_reg == 3'b111)  state_next   = data_end;
                else counter_next = counter_reg + 1'b1;
                
                
            end
            data_end: begin
                if (PS2_KBDAT == STOP) begin
                    
                    if (parity_reg) begin               //valid parity
                        code_next = (code_reg << 8) | data_reg;
                        
                        if (data_reg == 8'hE0 || data_reg == 8'hF0 ||  data_reg == 8'hE1 ||code_next[23:0] == 24'hE0F07C || code_next[15:0] == 16'hE012
                        || code_next[15:0] == 16'hE114 || code_next[23:0] == 24'hE11477 || code_next[47:0] == 48'hE11477E1F014) begin // treba primiti jos bajtova
                            
                            byte_num_next = byte_num_reg + 3'b001;
                        end
                        else begin
                            state_next        = waiting_for_start;
                            display_code_next = code_next[15:0];
                            byte_num_next     = 3'd0;
                        end
                        
                        
                        //E1 14 77 E1 F0 14 E0 77
                        
                    end
                    else begin                      //invalid parity
                        display_code_next = 16'hEEEE;
                        
                    end
                end
                state_next = waiting_for_start;
            end
            
        endcase
        
        
    end
    
endmodule
