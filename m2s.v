//design for master of apb

module master(
input wire pclk,
input wire prstn,
input sys_reg,
input sys_write,
input [31:0]sys_addr,
input [31:0]sys_wdata,
input [3:0]sys_wstrobe,
output reg [3:0]pstrobe,
output reg psel,
output reg p_en,
output reg pwrite,
output reg[31:0]paddr,
input wire pready,
input wire [31:0]prdata,
output reg [31:0]pwdata,
input wire psleverr);

localparam idle=2'd0,setup=2'd1,access=2'd2;
reg[1:0]current_state,next_state;

//sequential logic

always@(posedge pclk or negedge prstn)begin
	if(!prstn)begin
		current_state<=idle;
	end
	else begin
		current_state<=next_state;
	end
end

always@(*)begin
	case(current_state)
		idle:begin
		
			if(sys_reg==0)begin
				next_state=idle;
			end
			else begin
				next_state=setup;
			end
		end
		setup:begin
			next_state=access;
		end
		access:begin
			if(pready==0)begin
				next_state=access;
			end
			else begin
				next_state=idle;
			end
		end
		default:next_state=idle;
		
	endcase
end

always@(*)begin
	case(current_state)
		idle:begin
			psel=0;p_en=0;paddr=0;  pwrite=0;  pwdata=0;
				pstrobe=4'b0000;
		end
		setup:begin
			        psel=1;
				p_en=0;
				paddr=sys_addr;
				pwrite=sys_write;
				pwdata=sys_wdata;
				pstrobe=sys_wstrobe;
		end
		access:begin
			        psel=1;
				p_en=1;
				paddr=sys_addr;
				pwrite=sys_write;
				pwdata=sys_wdata;
				pstrobe=sys_wstrobe;
		end
		default:begin
			psel=0;p_en=0;
			paddr=0;  pwrite=0;  pwdata=0;	pstrobe=4'b0000;
		end
	endcase
end
endmodule

//------------------------------------------------

//design  of code apb_slave


module apb_slave (
    input  wire        pclk,
    input  wire        prstn,
    input  wire [31:0] paddr,
    input  wire        psel,
    input  wire        p_en,
    input  wire        pwrite,
    input  wire [31:0] pwdata,
    input wire  [3:0]pstrobe,
    output reg  [31:0] prdata,   // Making this a 'reg' so we can drive it in an always block later
    output reg        pready,
    output wire        psleverr
);
reg[31:0]controle_reg,data_reg;
wire write_enable;
reg [1:0]wait_counter;
//assign pready=1'b1;
assign psleverr=1'b0;
assign write_enable=(p_en & pwrite & psel & pready);




//block for write operation
always@(posedge pclk or negedge prstn)begin
	if(!prstn)begin
		controle_reg<=32'h00;
		data_reg<=32'h00;
	end
	else if(write_enable)begin
		case(paddr)
			32'h00:begin
			if(pstrobe[0]==1)	
				controle_reg[7:0]<=pwdata[7:0];
			if(pstrobe[1]==1)	
				controle_reg[15:8]<=pwdata[15:8];
			if(pstrobe[2]==1)	
				controle_reg[23:16]<=pwdata[23:16];
			if(pstrobe[3]==1)	
				controle_reg[31:24]<=pwdata[31:24];
		end
		32'h04:begin
			if(pstrobe[0]==1)
			       data_reg[7:0]<=pwdata[7:0];
			if(pstrobe[1]==1)
		               data_reg[15:8]<=pwdata[15:8];
			if(pstrobe[2]==1)
			       data_reg[23:16]<=pwdata[23:16];
			if(pstrobe[3]==1)
			       data_reg[31:24]<=pwdata[31:24];
	end

			
		endcase
	end
end


//block for read operation
always@(*)begin
		case(paddr)
			32'h00:prdata=controle_reg;
			32'h04:prdata=data_reg;
			default:prdata=32'h00;
		endcase
end

//always block for wait state with wait_counter

always@(posedge pclk or negedge prstn)begin
	if(!prstn)begin
		pready<=1'b1;
		wait_counter<=2'd0;
	end
	else if(psel==1&&p_en==0&&paddr==32'h04)begin
		pready<=1'b0;
		wait_counter<=2'd2;
	end
	else if(wait_counter>0)begin
		wait_counter<=wait_counter-1'b1;
		if(wait_counter==2'd1)begin
		pready<=1'b1;
              	end
	end

	else begin
		pready<=1'b1;
		wait_counter<=2'd0;
	end
end
endmodule

//-------------------------------------------------------------

//connection from master to slvae
module mas2slav(
input wire pclk,
input wire prstn,
input wire sys_reg,
input wire sys_write,
input wire [31:0]sys_addr,
input wire [31:0]sys_wdata,
input wire [3:0]sys_wstrobe,
output wire[31:0]sys_rdata,
output wire sys_ready);

wire psel,p_en,pwrite;
wire [31:0]paddr,pwdata,prdata;
wire  [3:0]pstrobe;
wire pready,psleverr;

assign sys_rdata=prdata;
assign sys_ready=pready;

master master_instance(.pclk(pclk),.prstn(prstn),.sys_reg(sys_reg),.sys_write(sys_write),.sys_addr(sys_addr),.sys_wdata(sys_wdata),.paddr(paddr),.psel(psel),.p_en(p_en),.pwdata(pwdata),.prdata(prdata),.pwrite(pwrite),.psleverr(psleverr),.pready(pready),.pstrobe(pstrobe),.sys_wstrobe(sys_wstrobe));


apb_slave slave_instance(.pclk(pclk),.prstn(prstn),.paddr(paddr),.psel(psel),.p_en(p_en),.pwrite(pwrite),.pwdata(pwdata),.prdata(prdata),.pready(pready),.psleverr(psleverr),.pstrobe(pstrobe));

endmodule


//-----------------------------------------------------


//test bench for master2slave

module top;
reg pclk,prstn,sys_reg,sys_write;
reg [31:0]sys_addr,sys_wdata;
reg [3:0]sys_wstrobe;
wire [31:0] sys_rdata;
wire sys_ready;

reg [31:0]capture_data=32'd0;//it strictly connect to top module only no connection with other module which used for inside task
// Local testbench variable to snapshot read data from the bus
mas2slav dut(.pclk(pclk),.prstn(prstn),.sys_reg(sys_reg),.sys_write(sys_write),.
sys_addr(sys_addr),.sys_wdata(sys_wdata),.sys_rdata(sys_rdata),.sys_ready(sys_ready),.sys_wstrobe(sys_wstrobe));

always #5 pclk=~pclk;

task cpu_write;
	input [31:0]addr;
	input [31:0]write;
	input [3:0]strobe;
	begin
        @(posedge pclk);
	sys_addr=addr;
	sys_wdata=write;
	sys_wstrobe=strobe;

	sys_write=1;
	sys_reg=1;
        @(posedge pclk);
	 @(posedge pclk);
	 #1;
	wait(sys_ready==1);
               
        @(posedge pclk);
	sys_reg=0;
	sys_write=0;
end
endtask

task cpu_read;
	input[31:0]addr;
	begin
		@(posedge pclk);
		sys_addr=addr;

		sys_write=0;
		sys_reg=1;
                @(posedge pclk);
                @(posedge pclk);
		#1;
		wait(sys_ready==1);
		capture_data=sys_rdata;

		@(posedge pclk);
		sys_write=0;
		sys_reg=0;
	end
endtask

initial begin
	pclk=0;prstn=0;sys_reg=0;sys_write=0;sys_wdata=0;sys_addr=0;sys_wstrobe=4'd0;
	#17;
	prstn=1;

	$display("\n--starting test 1:basic transfer--");
	cpu_write(32'h00,32'haaaaaaaa,4'b0011);
	cpu_read(32'h00);

	if(capture_data==32'h0000aaaa)
		$display("test 1 is pass wrote aaaaaaaa,read=%h",sys_rdata);
	else
		$display("test 1 is fail wrote  aaaaaaaa,got=%h",sys_rdata);

	$display("\n--- Starting Test 2: Corner Case ---");
        cpu_write(32'h04, 32'hFFFFFFFF,4'b1111);
        cpu_read(32'h04);
        
        if (capture_data == 32'hFFFFFFFF) 
            $display("test 2 pass: Data FFFFFFFF perfectly transferred");
        else 
            $display("test 2 fail: Expected FFFFFFFF, Got %0h", sys_rdata);
         
       	$display("\n--- Starting Test 3: Corner Case ---");
        cpu_write(32'h00, 32'hdddddddd,4'b1111);
        cpu_read(32'h00);
        
        if (capture_data == 32'hdddddddd) 
            $display("test 3 pass: Data dddddddd perfectly transferred");
        else 
            $display("test 3 fail: Expected dddddddd, Got %0h", sys_rdata);

        // --- E. END SIMULATION ---
        #100;
        $display("\n--- the process is completed ---");
        $finish;

end
endmodule

