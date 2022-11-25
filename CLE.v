`timescale 1ns/10ps
module CLE ( clk, reset, rom_q, rom_a, sram_a, sram_d, sram_wen, finish);
input         clk;
input         reset;
input  [7:0]  rom_q; // Data: 8 pixels every time
output [6:0]  rom_a; // Address: 0~127 times
output [9:0]  sram_a; // Address: nth pixel
output [7:0]  sram_d; // Label
output        sram_wen;
output        finish;

//----------output----------
reg [6:0] rom_a_r;
reg [9:0] sram_a_r;
reg [7:0] sram_d_r;
reg finish_r;
assign rom_a = rom_a_r;
assign sram_a = sram_a_r;
assign sram_d = sram_d_r;
assign sram_wen = 0;
assign finish = finish_r;

//----------others reg & wire----------
reg [3:0] state_r, state_w;

reg [10:0] cnt_pixel;
// reg [7:0]  cnt_input;
reg [8:0]  cnt_branch; 
reg [3:0]  cnt_9;
// reg [1:0]  cnt_3;
reg [4:0]  x,  y;
reg [4:0]  _x, _y;

wire [6:0] rom_index;
assign rom_index = {x, y[4:3]};

wire [3:0] y_index;
wire [3:0] y_index_m;
wire [3:0] y_index_l;
assign y_index   = 7 - _y[2:0];
assign y_index_m = y_index + 1;
assign y_index_l = y_index + 2;

wire [3:0] idx;
assign idx = 7 - cnt_9;
wire [3:0] idx_1;
assign idx_1 = 7 - y[2:0];

reg [9:0] temp [2:0];
reg [8:0] temp_r;

// for 9 pixel
reg [8:0] check_pixel;
reg [7:0] label;

//----------Sram reg & wire----------
reg [7:0] SramAddress_0_r;
reg [7:0] SramData_0_r;
reg SramWen_0_r; // 0 for wirte, 1 for read
wire [7:0] SramAddress_0;
wire [7:0] SramData_0, SramOut_0;
wire SramWen_0;
assign SramAddress_0 = SramAddress_0_r;
assign SramData_0 = SramData_0_r;
assign SramWen_0 = SramWen_0_r;

reg [8:0] SramAddress_x_r;
reg [7:0] SramData_x_r;
reg SramWen_x_r; // 0 for wirte, 1 for read
wire SramWen_x;
wire [8:0] SramAddress_x;
wire [7:0] SramData_x, SramOut_x;
assign SramAddress_x = SramAddress_x_r;
assign SramData_x = SramData_x_r;
assign SramWen_x = SramWen_x_r;

reg [8:0] SramAddress_y_r;
reg [7:0] SramData_y_r;
reg SramWen_y_r; // 0 for wirte, 1 for read
wire SramWen_y;
wire [8:0] SramAddress_y;
wire [7:0] SramData_y, SramOut_y;
assign SramAddress_y = SramAddress_y_r;
assign SramData_y = SramData_y_r;
assign SramWen_y = SramWen_x_r;

sram_256x8 mysram0(
   .A(SramAddress_0),
   .D(SramData_0),
   .CLK(clk),
   .CEN(1'b0),
   .WEN(SramWen_0),
   .Q(SramOut_0)
);

sram_512x8 branch_x(
   .A(SramAddress_x),
   .D(SramData_x),
   .CLK(clk),
   .CEN(1'b0),
   .WEN(SramWen_x),
   .Q(SramOut_x)
);

sram_512x8 branch_y(
    .A(SramAddress_y),
   .D(SramData_y),
   .CLK(clk),
   .CEN(1'b0),
   .WEN(SramWen_y),
   .Q(SramOut_y)
);

parameter   idle         = 4'd0, 
            readP        = 4'd1, 
            read_mysram  = 4'd2, 
            read_3_row   = 4'd3, 
            check_y      = 4'd4,
            check_y_2    = 4'd5,
            check_x      = 4'd6,
            get_xy       = 4'd7,
            check_9      = 4'd8, 
            branch       = 4'd9,
            branch_index = 4'd10,
            branch_pre   = 4'd11,
            branch_end   = 4'd12,
            END          = 4'd13;


always@ (*) begin
    
    case (state_r)
        idle        : state_w = readP;
        readP       : state_w = (cnt_pixel == 128)? read_mysram : readP;
        read_mysram : state_w = (cnt_pixel > 1023)? END: (!SramOut_0)? read_mysram : (SramOut_0[idx_1])? read_3_row : read_mysram;
        read_3_row  : state_w = (cnt_9 == 2)? (_y[2:0] == 0 || _y[2:0] == 7)? check_y : 
                                (!_x || _x==31)? check_x : get_xy : read_3_row;
        check_y     : state_w = check_y_2;
        check_y_2   : state_w = (cnt_9 == 2)? check_x : check_y_2;
        check_x     : state_w = get_xy;
        get_xy      : state_w = check_9;
        check_9     : state_w = (cnt_9 == 9)? branch : check_9;
        branch      : state_w = (!cnt_branch)? branch_end : branch_index;
        branch_index: state_w = branch_pre;
        branch_pre  : state_w = (!SramOut_0[y_index])? branch : read_3_row;
        branch_end  : state_w = read_mysram;
        END         : state_w = END;
    endcase
end

always@ (negedge clk or posedge reset) begin
    if(reset) begin
        state_r     <= 0;
        rom_a_r     <= rom_index;
        sram_a_r    <= 0;
        sram_d_r    <= 0;
        finish_r    <= 0;

        cnt_pixel   <= 0;
        // cnt_input   <= 0;
        cnt_branch  <= 0;
        cnt_9       <= 0;
        // cnt_3       <= 0;
        x           <= 0;
        y           <= 0;
        _x          <= 0;
        _y          <= 0;
        temp_r      <= 0;
        check_pixel <= 0;
        label       <= 2;

        SramAddress_0_r <= 0;
        SramData_0_r    <= 0;
        SramWen_0_r     <= 0;
        SramAddress_x_r <= 0;
        SramData_x_r    <= 0;
        SramWen_x_r     <= 0;
        SramAddress_y_r <= 0;
        SramData_y_r    <= 0;
        SramWen_y_r     <= 0;
        
    end else begin
        state_r <= state_w;
        case (state_r)
            readP: begin
                if (cnt_pixel == 128) begin
                    rom_a_r <= 0;
                    cnt_pixel <= 0;
                    {x,y} <= 0;
                    SramWen_0_r <= 1; //read
                    SramAddress_0_r <= 0;
                end else begin
                    SramAddress_0_r <= cnt_pixel;
                    SramData_0_r <= rom_q;
                    if (cnt_9 == 7) begin
                        cnt_9 <= 0;
                        {x,y} <= {x,y} + 1;
                        rom_a_r <= cnt_pixel + 1;
                        cnt_pixel <= cnt_pixel + 1;
                        sram_a_r <= {x,y};
                        sram_d_r <= rom_q[idx];
                    end else begin
                        cnt_9 <= cnt_9 + 1;
                        {x,y} <= {x,y} + 1;
                        sram_a_r <= {x,y};
                        sram_d_r <= rom_q[idx];
                    end
                end
            end
            read_mysram: begin //2
                if (!SramOut_0) begin
                    cnt_pixel <= cnt_pixel + 8; 
                    // {x,y} <= {x,y} + 8;
                    // x <= x + 1;
                    {x, y[4:3]} <= {x, y[4:3]} + 1;
                    y[2:0] <= 0;
                    SramAddress_0_r <= rom_index + 1;
                    // {x,y}==1024 ->finish
                end else begin
                    if (SramOut_0[idx_1]) begin
                        label <= label + 1;
                        SramAddress_0_r <= rom_index - 4;
                        _x <= x;
                        _y <= y;
                    end else begin
                        cnt_pixel <= cnt_pixel + 1;
                        {x,y} <= {x,y} + 1;
                    end
                end
            end
            read_3_row: begin //3
                if (cnt_9 == 2) begin
                    cnt_9 <= 0;
                    temp_r <= temp[1][8:1];
                    temp[cnt_9] <= {SramOut_0, 1'b0};
                end else begin
                    cnt_9 <= cnt_9 + 1;
                    temp[cnt_9] <= {SramOut_0, 1'b0};
                    SramAddress_0_r <= SramAddress_0_r + 4;
                end
            end
            check_y: begin //4
                if (_y[2:0] == 7) begin
                    SramAddress_0_r <= SramAddress_0_r - 4 - 3;
                end else if (_y[2:0] == 0) begin
                    SramAddress_0_r <= SramAddress_0_r - 4 - 5;
                end
            end
            check_y_2: begin //5
                if (_y[2:0] == 7) begin
                    if (cnt_9 == 2) begin
                        cnt_9 <= 0;
                        temp[cnt_9][0] <= SramOut_0[7];
                    end else begin
                        cnt_9 <= cnt_9 + 1;
                        temp[cnt_9][0] <= SramOut_0[7];
                        SramAddress_0_r <= SramAddress_0_r + 4;
                    end 
                end else if (_y[2:0] == 0) begin
                    if (cnt_9 == 2) begin
                        cnt_9 <= 0;
                        temp[cnt_9][9] <= SramOut_0[0];
                    end else begin
                        cnt_9 <= cnt_9 + 1;
                        temp[cnt_9][9] <= SramOut_0[0];
                        SramAddress_0_r <= SramAddress_0_r + 4;
                    end 
                end
            end
            check_x: begin //6
                if (!_y) begin 
                    temp[0][9] <= 0;
                    temp[1][9] <= 0;
                    temp[2][9] <= 0;
                end else if (_y == 31) begin
                    temp[0][0] <= 0;
                    temp[1][0] <= 0;
                    temp[2][0] <= 0;
                end

                if (!_x) begin 
                    temp[0] <= 0;
                end
                else if(_x == 31) begin
                    temp[2] <= 0;
                end

            end
            get_xy: begin //7
                temp_r[y_index] <= 0;
                // SramData_0_r <= 
                sram_a_r <= {_x,_y};
                sram_d_r <= label;
                check_pixel[0] <= temp[0][y_index_l];
                check_pixel[1] <= temp[0][y_index_m];
                check_pixel[2] <= temp[0][y_index];
                check_pixel[3] <= temp[1][y_index_l];
                check_pixel[4] <= 0;
                check_pixel[5] <= temp[1][y_index];
                check_pixel[6] <= temp[2][y_index_l];
                check_pixel[7] <= temp[2][y_index_m];
                check_pixel[8] <= temp[2][y_index];
            end
            check_9: begin //8
                if (cnt_9 == 9) begin
                    cnt_9 <= 0;
                    SramWen_0_r <= 0; //write
                    SramAddress_0_r <= {_x, _y[4:3]};
                    SramData_0_r <= temp_r; // change(x,y)=0 in sram0
                    SramWen_x_r <= 1; //read
                    SramWen_y_r <= 1; //read
                end else begin
                    cnt_9 <= cnt_9 + 1;
                    if (check_pixel[cnt_9]) begin
                        SramWen_x_r <= 0; //write
                        SramAddress_x_r <= cnt_branch + 1;
                        SramData_x_r <= _x + cnt_9 / 3 - 1;

                        SramWen_y_r <= 0; //write
                        SramAddress_y_r <= cnt_branch + 1;
                        if (cnt_9 == 0 || cnt_9 == 3 || cnt_9 == 6)begin
                            SramData_y_r <= _y - 1;
                        end else if (cnt_9 == 1 || cnt_9 == 4 || cnt_9 == 7)begin
                            SramData_y_r <= _y;
                        end else if (cnt_9 == 2 || cnt_9 == 5 || cnt_9 == 8)begin
                            SramData_y_r <= _y + 1;
                        end
                        cnt_branch <= cnt_branch + 1;
                    end else begin
                        SramWen_x_r <= 1; //read
                        SramWen_y_r <= 1; //read
                    end
                end
            end
            branch: begin //9
                SramWen_0_r <= 1; //read
                if (cnt_branch == 0) begin
                    {x,y} <= {x,y} + 1;
                    cnt_pixel <= cnt_pixel + 1;
                end else begin
                    cnt_branch <= cnt_branch - 1;
                    SramAddress_x_r <= cnt_branch;
                    SramAddress_y_r <= cnt_branch;
                end
            end
            branch_index: begin // 10
                _x <= SramOut_x;
                _y <= SramOut_y;
                SramAddress_0_r <= {1'b0, SramOut_x[4:0], SramOut_y[4:3]};
            end
            branch_pre: begin // 11
                if (SramOut_0[y_index]) begin
                    SramAddress_0_r <= {1'b0, SramOut_x[4:0], SramOut_y[4:3]} - 4;
                end
            end
            branch_end: begin
                SramAddress_0_r <= {x,y[4:3]};
            end
            END: begin //12
                finish_r <= 1;
            end
        endcase
    end
end

endmodule
