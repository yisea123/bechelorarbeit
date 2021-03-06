module WaveController(
	CLK,
	RST_n,
	Channel,
	Waveform,
	AmpX10,
	Freq,
	Duty,
	BusySgn,
	DAC_Data,
	TriggerSign
	);

	input CLK;
	input RST_n;
	input [1:0] Channel;
	input [7:0] Waveform;
	input [7:0] AmpX10;
	input [7:0] Freq;
	input [7:0] Duty;
	input BusySgn;
	output [15:0] DAC_Data;
	output TriggerSign;
	wire Ctrl_CLK;
	
	wire [15:0] SineBufData;
	wire [9:0]	SineBufAddr;		
	SINE_ROM sine_rom(
		.address(SineBufAddr),
		.clock(CLK),
		.q(SineBufData));
		
	wire [15:0] TriBufData;
	wire [9:0]	TriBufAddr;
	TRI_ROM tri_rom(
		.address(TriBufAddr),
		.clock(CLK),
		.q(TriBufData));

 /* Ctrl_CLK = 1KHz; */		
	reg[15:0] clk_cnt;	// create clk_1kHz and trigger signal.
	reg ctrl_clk, trigger_signal;	
	always@(posedge CLK or negedge RST_n)
		if(!RST_n)begin
			ctrl_clk <= 1'b0;		
			clk_cnt <= 16'b0;
			trigger_signal <= 1'b0;
			end
		else if((ctrl_clk == 1)&(clk_cnt==12250))begin
			clk_cnt <= clk_cnt + 1'b1;
			trigger_signal <= 1'b1;								// trigger singal, freq 1KHz ,width 20us.
			end
		else if(clk_cnt == (12500-1)) begin
			clk_cnt <= 16'b0;
			ctrl_clk <= ~ctrl_clk;
			trigger_signal <= 1'b0;
			end
		else 
			clk_cnt <= clk_cnt + 1'b1;
	
	assign Ctrl_CLK = ctrl_clk;	
	
	reg[15:0] rand_num;
	always@(posedge CLK or negedge RST_n)
		begin
			 if(!RST_n)begin
					  rand_num    <=16'b0;
					  rand_num <=16'hD2A6;    /*load the initial value when load is active*/
				  end
			 else begin
						rand_num[0] <= rand_num[15];
						rand_num[1] <= rand_num[0];
						rand_num[2] <= rand_num[1]^rand_num[10];
						rand_num[3] <= rand_num[2];
						rand_num[4] <= rand_num[3]^rand_num[7];
						rand_num[5] <= rand_num[4]^rand_num[15];
						rand_num[6] <= rand_num[5]^rand_num[15];
						rand_num[7] <= rand_num[6]^rand_num[13];
						rand_num[8] <= rand_num[7];
						rand_num[9] <= rand_num[8]^rand_num[3];
						rand_num[10] <= rand_num[9];
						rand_num[11] <= rand_num[10];
						rand_num[12] <= rand_num[11]^rand_num[15];
						rand_num[13] <= rand_num[12]^rand_num[14];
						rand_num[14] <= rand_num[13]^rand_num[15];
						rand_num[15] <= rand_num[14];
				  end         
		end
					  
				
	parameter idleMode = 8'd0;
	parameter sineWave = 8'd1;
	parameter triWave = 8'd2;
	parameter squareWave = 8'd3;
	parameter DC_Mode = 8'd4;
	parameter noiseMode = 8'd5;
	parameter BufNum = 10'd1000;
			
	
	reg[10:0] sine_addr,tri_addr,c_square_p, n_square_p;
	reg[11:0] sine_data,tri_data,square_data,dc_data,l_da_data,noise_data;
	reg[15:0] dac_data;
	reg[64:0] cal_temp;
	always@(posedge Ctrl_CLK or negedge RST_n)
		if(!RST_n)begin
			sine_addr 	<= 11'b0;
			tri_addr 	<= 11'b0;
			c_square_p 	<= 11'b0;
			n_square_p 	<= 11'b0;
			sine_data 	<= 11'b0;
			tri_data  	<= 11'b0;
			square_data <= 11'b0;
			dc_data 		<= 11'b0;
			l_da_data 	<= 11'b0;
			dac_data		<= 16'b0;
			end
		else begin 
		case(Waveform)
			idleMode:begin
				dac_data = {Channel,2'b00,12'h7ff};
				end
			sineWave:begin			
				sine_addr = sine_addr + Freq;
				if(sine_addr>=BufNum)
					sine_addr = sine_addr % BufNum;
				cal_temp = SineBufData;
				cal_temp = cal_temp - 32768;
				cal_temp = cal_temp * AmpX10 * 8;
				cal_temp = cal_temp >> 15;
				cal_temp = cal_temp + 2048;
				sine_data = cal_temp[11:0];
				dac_data = {Channel,2'b0,sine_data};
				end
			triWave:begin
				tri_addr = tri_addr + Freq;
				if(tri_addr>=BufNum)
					tri_addr = tri_addr % BufNum;
				cal_temp = TriBufData;
				cal_temp = cal_temp - 32768;
				cal_temp = cal_temp * AmpX10 * 8;
				cal_temp = cal_temp >> 15;
				cal_temp = cal_temp + 2048;
				tri_data = cal_temp[11:0];

				dac_data = {Channel,2'b0,tri_data};
				end
			squareWave:begin
				n_square_p = c_square_p + Freq;
				if(n_square_p >= BufNum)
					n_square_p = n_square_p % BufNum;
				c_square_p = n_square_p;
				if(c_square_p < Duty*10)
					cal_temp = AmpX10 * 8 + 2048;
				else	
					cal_temp = -AmpX10 * 8 + 2048;
				square_data = cal_temp[11:0];
				dac_data = {Channel,2'b0,square_data};
				end
			DC_Mode:begin
				cal_temp = AmpX10 * 8 + 2048;
				dc_data = cal_temp[11:0];
				//dc_data = 0.9 * dc_data + 0.1 *  l_da_data;
				//l_da_data = dc_data;
				dac_data = {Channel,2'b0,dc_data};
				end
			noiseMode:begin
				cal_temp = rand_num;
				cal_temp = cal_temp - 32768;
				cal_temp = cal_temp * AmpX10 * 10;
				cal_temp = cal_temp >> 14;
				cal_temp = cal_temp + 2048;
				noise_data = cal_temp[11:0];
				dac_data = {Channel,2'b0,noise_data};
				end
			default:;
			endcase
		end
		
	
	assign SineBufAddr = sine_addr[9:0];
	assign TriBufAddr  = tri_addr[9:0];
	assign DAC_Data = dac_data;
	assign TriggerSign = trigger_signal;
endmodule




// http://bbs.eeworld.com.cn/thread-510525-1-1.html
			