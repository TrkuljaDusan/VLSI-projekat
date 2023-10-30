module top_monitor; 


reg KBCLK, KBDAT, RST_N, clk; wire [15:0] HEX; 
// reg[63:0] data_send = 64'b11111111111111111111111111_0_0000_1111_1_11111111_1111_111_0_10110100_1_1_1111;

// reg[63:0] data_send= 64'b111111_0_0000_0111_0_1__0_0000_1111_1_1_0_0000_1110_0_11111111111111111111;
// ps2 ps2_inst(.PS2_KBCLK(PS2_KBCLK_DEB), .PS2_KBDAT(PS2_KBDAT), .clk(CLOCK_50), .rst_n(BUTTON[0]), .hex(hex_out));
integer i;
integer w;

reg[8:0]  data[8:0];


// reg[79:0] data_send = 80'b1111_0_1110_1110_1_1_0_0000_0111_0_1_0_0010_1000_1_1_0_0000_1111_1_1_0_1000_0111_1_1_0_1110_1110_1_1_0_0010_1000_1_1_0_1000_0111_1_1111;
ps2 ps2_inst(.PS2_KBCLK(KBCLK), .PS2_KBDAT(KBDAT), .clk(clk), .rst_n(RST_N), .hex(HEX));



initial begin
    data[0]=8'hE0;
    data[1]=8'h11;
    data[2]=8'hE0;
    data[3]=8'hF0;
    data[4]=8'h11;
    data[5]=8'hff;
    data[6]=8'hff;
    data[7]=8'hff;
  

    // data[0]=8'hE1;
    // data[1]=8'H14;
    // data[2]=8'h77;
    // data[3]=8'hE1;
    // data[4]=8'hF0;
    // data[5]=8'h14;
    // data[6]=8'hE0;
    // data[7]=8'h77;
    clk                 = 1'b0;
    KBDAT = 1'b1;
    KBCLK = 1'b1;
    for (w=0; w<8; w=w+1)begin
        
        KBDAT =1'b0; //start;
        #5 KBCLK = ~KBCLK;      //0
        #5 KBCLK = ~KBCLK;      //0
        for (i = 0; i<8;i = i+1) begin
            KBDAT    = data[w][i];
            #5 KBCLK = ~KBCLK;      //0
            #5 KBCLK = ~KBCLK;      //0
        end
        KBDAT = ^data[w] ^1; //parity
        #5 KBCLK = ~KBCLK;      //0
        #5 KBCLK = ~KBCLK;      //0
        KBDAT = 1'b1;
        #5 KBCLK = ~KBCLK;      //0
        #5 KBCLK = ~KBCLK;      //0
    end
    $finish;
end
initial 
    $monitor("State= %d, Ulaz[%2d]=%b, data_reg = %h, code=%h, parity_reg=%b,Izlaz = %h"
    ,ps2_inst.state_reg,i, KBDAT,ps2_inst.data_reg,ps2_inst.code_reg, ps2_inst.parity_reg, HEX);

always #1 clk = ~clk;
endmodule
