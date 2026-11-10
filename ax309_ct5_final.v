// ================================================================
// CT5 FINAL - CPU 8-bit / instructions 16-bit / AX309 Spartan-6
// Source: CT5 final.circ (Logisim 2.7.1)
// Verilog-2001, Xilinx ISE 14.7 / XST
// Top module: ax309_top
//
// Important: Only add THIS Verilog source to the ISE project.
// Remove old top_module.v / ax309_cpu.v to avoid duplicate modules.
// The instruction ROM is initialized INSIDE this file. No .mem
// file is required for synthesis or programming the FPGA.
// ================================================================

// Active-low pushbutton -> one-cycle pulse on a debounced PRESS.
module ct5_button_pulse #(parameter integer COUNT_MAX = 1000000)(
    input clk, input rst, input key_n, output reg pressed
);
    reg sync1, sync2, stable_n;
    reg [19:0] counter;    // 1,000,000 <= 2^20
    always @(posedge clk) begin
        if (rst) begin
            sync1 <= 1'b1;
            sync2 <= 1'b1;
            stable_n <= 1'b1;
            counter <= 20'd0;
            pressed <= 1'b0;
        end else begin
            sync1 <= key_n;
            sync2 <= sync1;
            pressed <= 1'b0;
            if (sync2 == stable_n) begin
                counter <= 20'd0;
            end else if (counter == COUNT_MAX - 1) begin
                counter <= 20'd0;
                stable_n <= sync2;
                if (sync2 == 1'b0)
                    pressed <= 1'b1;
            end else begin
                counter <= counter + 20'd1;
            end
        end
    end
endmodule

// Program ROM: exactly 43 words stored in CT5 final.circ, followed
// by 213 zero words. 16-bit encoding {opcode,rs,rt,imm8}.
module ct5_instruction_rom(
    input clk, input [7:0] addr, output reg [15:0] q
);
    (* ROM_STYLE = "BLOCK" *) reg [15:0] rom [0:255];
    integer i;
    initial begin
        for (i=0; i<256; i=i+1)
            rom[i] = 16'h0000;
        rom[8'h00] = 16'h2105;
        rom[8'h01] = 16'h2203;
        rom[8'h02] = 16'h0600;
        rom[8'h03] = 16'h1600;
        rom[8'h04] = 16'h210C;
        rom[8'h05] = 16'h220A;
        rom[8'h06] = 16'h6600;
        rom[8'h07] = 16'h7600;
        rom[8'h08] = 16'h2105;
        rom[8'h09] = 16'h222A;
        rom[8'h0A] = 16'h5600;
        rom[8'h0B] = 16'h2200;
        rom[8'h0C] = 16'h4600;
        rom[8'h0D] = 16'h2108;
        rom[8'h0E] = 16'h2202;
        rom[8'h0F] = 16'hC600;
        rom[8'h10] = 16'h2202;
        rom[8'h11] = 16'hA600;
        rom[8'h12] = 16'h2104;
        rom[8'h13] = 16'h2204;
        rom[8'h14] = 16'h8602;
        rom[8'h15] = 16'h23EE;
        rom[8'h16] = 16'h23EE;
        rom[8'h17] = 16'h2205;
        rom[8'h18] = 16'hB602;
        rom[8'h19] = 16'h23EE;
        rom[8'h1A] = 16'h23EE;
        rom[8'h1B] = 16'h901E;
        rom[8'h1C] = 16'h23EE;
        rom[8'h1D] = 16'h23EE;
        rom[8'h1E] = 16'h8601;
        rom[8'h1F] = 16'h2204;
        rom[8'h20] = 16'hB602;
        rom[8'h21] = 16'h1500;
        rom[8'h22] = 16'hD025;
        rom[8'h23] = 16'h23EE;
        rom[8'h24] = 16'h23EE;
        rom[8'h25] = 16'h2101;
        rom[8'h26] = 16'hD029;
        rom[8'h27] = 16'h230A;
        rom[8'h28] = 16'h902A;
        rom[8'h29] = 16'h23EE;
        rom[8'h2A] = 16'h902A;   // J 0x2A: Logisim infinite end-loop
    end
    always @(posedge clk)
        q <= rom[addr];  // synchronous ROM read: handle FETCH latency
endmodule

// RegisterFile Logisim: R0=0; R1,R2,R3 programmable 8-bit regs.
module ct5_register_file(
    input clk, input rst, input we,
    input [1:0] rs, input [1:0] rt,
    input [7:0] wd,
    output reg [7:0] a, output reg [7:0] b,
    output [7:0] r1, output [7:0] r2, output [7:0] r3
);
    reg [7:0] x1, x2, x3;
    always @(posedge clk) begin
        if (rst) begin
            x1 <= 8'h00;
            x2 <= 8'h00;
            x3 <= 8'h00;
        end else if (we) begin
            case (rt)
                2'd1: x1 <= wd;
                2'd2: x2 <= wd;
                2'd3: x3 <= wd;
                default: ; // R0 cannot be written
            endcase
        end
    end
    always @(*) begin
        case (rs)
            2'd0: a = 8'h00;
            2'd1: a = x1;
            2'd2: a = x2;
            2'd3: a = x3;
            default: a = 8'h00;
        endcase
        case (rt)
            2'd0: b = 8'h00;
            2'd1: b = x1;
            2'd2: b = x2;
            2'd3: b = x3;
            default: b = 8'h00;
        endcase
    end
    assign r1 = x1;
    assign r2 = x2;
    assign r3 = x3;
endmodule

// Logisim ALU 3-bit multiplexer selects:
// 0=AND, 1=ADD, 2=SUB, 3=OR, 4=SHL, 5=SHR.
// Shift count is B[2:0], taken from Rt for register operations.
module ct5_alu(
    input [7:0] a, input [7:0] b,
    input [2:0] op,
    output reg [7:0] y, output zero
);
    always @(*) begin
        case (op)
            3'd0: y = a & b;
            3'd1: y = a + b;
            3'd2: y = a - b;
            3'd3: y = a | b;
            3'd4: y = a << b[2:0];
            3'd5: y = a >> b[2:0];
            default: y = 8'h00;
        endcase
    end
    assign zero = (y == 8'h00);
endmodule

// Exact 16-bit control ROM words, extracted from ControlUnit Logisim.
// Bits:
//  [2] RegWrite [4] MemWrite [5] MemToReg
//  [10:8] ALUControl [11] Jump [12] JZ
//  [13] ALUSrc [14] BEQ [15] BNE
module ct5_control_unit(
    input [3:0] opcode,
    output regwrite, output memwrite, output memtoreg,
    output alusrc, output beq, output bne,
    output jump, output jz, output [2:0] alucontrol
);
    reg [15:0] ctrl;
    always @(*) begin
        case (opcode)
            4'h0: ctrl = 16'h0104; // ADD
            4'h1: ctrl = 16'h0204; // SUB
            4'h2: ctrl = 16'h2104; // ADDI
            4'h3: ctrl = 16'h0000; // NOP
            4'h4: ctrl = 16'h2124; // LW
            4'h5: ctrl = 16'h2110; // SW
            4'h6: ctrl = 16'h0004; // AND
            4'h7: ctrl = 16'h0304; // OR
            4'h8: ctrl = 16'h4200; // BEQ
            4'h9: ctrl = 16'h0800; // J
            4'hA: ctrl = 16'h0504; // SHR
            4'hB: ctrl = 16'h8200; // BNE
            4'hC: ctrl = 16'h0404; // SHL
            4'hD: ctrl = 16'h1000; // JZ (saved Z_FLAG)
            4'hE: ctrl = 16'h0000;
            4'hF: ctrl = 16'h0000;
            default: ctrl = 16'h0000;
        endcase
    end
    assign regwrite   = ctrl[2];
    assign memwrite   = ctrl[4];
    assign memtoreg   = ctrl[5];
    assign alucontrol = ctrl[10:8];
    assign jump       = ctrl[11];
    assign jz         = ctrl[12];
    assign alusrc     = ctrl[13];
    assign beq        = ctrl[14];
    assign bne        = ctrl[15];
endmodule

// DataMemory: 256x8, synchronous block RAM.
// Read and write in separate always blocks for XST RAM inference.
module ct5_data_memory(
    input clk, input we, input [7:0] addr,
    input [7:0] wd, output reg [7:0] q
);
    (* RAM_STYLE = "BLOCK" *) reg [7:0] ram [0:255];
    integer i;
    initial begin
        for (i=0; i<256; i=i+1)
            ram[i] = 8'h00;
    end
    always @(posedge clk) begin
        if (we)
            ram[addr] <= wd;
    end
    always @(posedge clk)
        q <= ram[addr];
endmodule

// Instruction level START/DONE interface: one START => one complete instruction.
// FETCH stage is required because instruction ROM is synchronous.
// LOAD_WB stage is required for synchronous data RAM reads.
module ct5_cpu_core(
    input clk, input rst, input start,
    output reg [7:0] pc, output [15:0] instr,
    output [7:0] r1, output [7:0] r2, output [7:0] r3,
    output [7:0] alu_debug, output [7:0] mem_debug,
    output reg z_flag,
    output reg busy, output reg done, output reg halted
);
    localparam ST_IDLE = 2'd0;
    localparam ST_FETCH = 2'd1;
    localparam ST_EXEC = 2'd2;
    localparam ST_LOAD_WB = 2'd3;

    reg [1:0] state;
    wire [15:0] rom_q;
    wire [3:0] op = rom_q[15:12];
    wire [1:0] rs = rom_q[11:10];
    wire [1:0] rt = rom_q[9:8];
    wire [7:0] imm = rom_q[7:0];
    wire [7:0] a, b, operand_b, alu_y;
    wire [7:0] ram_q;
    wire regwrite, memwrite, memtoreg, alusrc, beq, bne, jump, jz;
    wire [2:0] alucontrol;
    wire alu_zero;
    wire take_branch = (beq && alu_zero) || (bne && !alu_zero);
    wire take_abs_jump = jump || (jz && z_flag);
    wire [7:0] next_pc = take_abs_jump ? imm :
             take_branch ? (pc + 8'd1 + imm) : (pc + 8'd1);
    wire reg_en = !rst && regwrite &&
                ((state == ST_EXEC && !memtoreg) ||
                 (state == ST_LOAD_WB && memtoreg));
    wire [7:0] reg_wd = (state == ST_LOAD_WB) ? ram_q : alu_y;
    wire ram_we = !rst && (state == ST_EXEC) && memwrite;
    reg [7:0] last_alu;

    ct5_instruction_rom rom(.clk(clk), .addr(pc), .q(rom_q));
    ct5_control_unit cu(
        .opcode(op), .regwrite(regwrite), .memwrite(memwrite),
        .memtoreg(memtoreg), .alusrc(alusrc), .beq(beq), .bne(bne),
        .jump(jump), .jz(jz), .alucontrol(alucontrol)
    );
    ct5_register_file rf(
        .clk(clk), .rst(rst), .we(reg_en), .rs(rs), .rt(rt),
        .wd(reg_wd), .a(a), .b(b), .r1(r1), .r2(r2), .r3(r3)
    );
    assign operand_b = alusrc ? imm : b;
    ct5_alu alu(
        .a(a), .b(operand_b), .op(alucontrol),
        .y(alu_y), .zero(alu_zero)
    );
    ct5_data_memory dm(
        .clk(clk), .we(ram_we), .addr(alu_y), .wd(b), .q(ram_q)
    );
    assign instr = rom_q;
    assign alu_debug = last_alu;  // latched result: observable while CPU waits
    assign mem_debug = ram_q;

    always @(posedge clk) begin
        if (rst) begin
            pc <= 8'h00;
            state <= ST_IDLE;
            busy <= 1'b0;
            done <= 1'b0;
            halted <= 1'b0;
            z_flag <= 1'b0;
            last_alu <= 8'h00;
        end else begin
            done <= 1'b0;
            case (state)
                ST_IDLE: begin
                    if (start && !halted) begin
                        busy <= 1'b1;
                        state <= ST_FETCH;
                    end
                end
                ST_FETCH: begin
                    // At this edge, ROM q already holds the instruction for PC.
                    state <= ST_EXEC;
                end
                ST_EXEC: begin
                    pc <= next_pc;
                    last_alu <= alu_y;
                    z_flag <= alu_zero;
                    // End-of-program convention for AX309: the Logisim
                    // program terminates with J to its own address (0x2A).
                    if (jump && imm == pc)
                        halted <= 1'b1;
                    if (memtoreg) begin
                        state <= ST_LOAD_WB;
                    end else begin
                        state <= ST_IDLE;
                        busy <= 1'b0;
                        done <= 1'b1;
                    end
                end
                ST_LOAD_WB: begin
                    // RAM q from the preceding ST_EXEC edge is available.
                    state <= ST_IDLE;
                    busy <= 1'b0;
                    done <= 1'b1;
                end
                default: begin
                    state <= ST_IDLE;
                    busy <= 1'b0;
                end
            endcase
        end
    end
endmodule

// 6-digit multiplexed active-low seven-segment display.
// dig[7:0]={DP,G,F,E,D,C,B,A}; sel is active-low.
module ct5_sevenseg6 #(parameter integer SCAN_DIV=50000)(
    input clk, input rst, input [23:0] value,
    output reg [7:0] dig, output reg [5:0] sel
);
    reg [15:0] div_count;
    reg [2:0] scan;
    reg [3:0] hex;
    reg [7:0] pattern;
    always @(posedge clk) begin
        if (rst) begin
            div_count <= 16'd0;
            scan <= 3'd0;
        end else if (div_count == SCAN_DIV - 1) begin
            div_count <= 16'd0;
            if (scan == 3'd5) scan <= 3'd0;
            else scan <= scan + 3'd1;
        end else begin
            div_count <= div_count + 16'd1;
        end
    end
    always @(*) begin
        sel = 6'b111111;
        hex = 4'h0;
        case (scan)
            3'd0: begin sel=6'b111110; hex=value[3:0]; end
            3'd1: begin sel=6'b111101; hex=value[7:4]; end
            3'd2: begin sel=6'b111011; hex=value[11:8]; end
            3'd3: begin sel=6'b110111; hex=value[15:12]; end
            3'd4: begin sel=6'b101111; hex=value[19:16]; end
            3'd5: begin sel=6'b011111; hex=value[23:20]; end
            default: begin sel=6'b111111; hex=4'h0; end
        endcase
        case (hex)
            4'h0: pattern=8'hC0; 4'h1: pattern=8'hF9;
            4'h2: pattern=8'hA4; 4'h3: pattern=8'hB0;
            4'h4: pattern=8'h99; 4'h5: pattern=8'h92;
            4'h6: pattern=8'h82; 4'h7: pattern=8'hF8;
            4'h8: pattern=8'h80; 4'h9: pattern=8'h90;
            4'hA: pattern=8'h88; 4'hB: pattern=8'h83;
            4'hC: pattern=8'hC6; 4'hD: pattern=8'hA1;
            4'hE: pattern=8'h86; 4'hF: pattern=8'h8E;
            default: pattern=8'hFF;
        endcase
        dig = pattern;
    end
endmodule

// ================================================================
// AX309 hardware top: compatible with the earlier, working UCF.
// KEY1 = one instruction, KEY2 = reset+auto, KEY3 = pause/resume,
// KEY4 = cycle display pages 0 / 1 / 2.
// ================================================================
module ax309_top #(
    parameter integer AUTO_DIV = 12500000,   // 0.25 s per instruction @ 50 MHz
    parameter integer DEBOUNCE_CYCLES = 1000000, // 20ms @ 50 MHz
    parameter integer SCAN_DIV = 50000
)(
    input clk50, input reset_n,
    input key1_n, input key2_n, input key3_n, input key4_n,
    output [7:0] dig, output [5:0] sel, output [3:0] led
);
    // Synchronize external RESET (active low).
    reg reset_ff1, reset_ff2;
    always @(posedge clk50) begin
        reset_ff1 <= ~reset_n;
        reset_ff2 <= reset_ff1;
    end
    wire rst = reset_ff2;
    wire step_evt, auto_evt, pause_evt, display_evt;
    ct5_button_pulse #(.COUNT_MAX(DEBOUNCE_CYCLES)) btn_step(
        .clk(clk50),.rst(rst),.key_n(key1_n),.pressed(step_evt));
    ct5_button_pulse #(.COUNT_MAX(DEBOUNCE_CYCLES)) btn_auto(
        .clk(clk50),.rst(rst),.key_n(key2_n),.pressed(auto_evt));
    ct5_button_pulse #(.COUNT_MAX(DEBOUNCE_CYCLES)) btn_pause(
        .clk(clk50),.rst(rst),.key_n(key3_n),.pressed(pause_evt));
    ct5_button_pulse #(.COUNT_MAX(DEBOUNCE_CYCLES)) btn_display(
        .clk(clk50),.rst(rst),.key_n(key4_n),.pressed(display_evt));

    reg [23:0] auto_counter;
    reg auto_run;
    reg [1:0] display_page;
    reg soft_reset, cpu_start;
    wire [7:0] pc, r1, r2, r3, alu_last, memory_q;
    wire [15:0] instruction;
    wire cpu_busy, cpu_done, cpu_halt, z_flag;

    ct5_cpu_core cpu(
        .clk(clk50), .rst(rst | soft_reset), .start(cpu_start),
        .pc(pc), .instr(instruction), .r1(r1), .r2(r2), .r3(r3),
        .alu_debug(alu_last), .mem_debug(memory_q),
        .z_flag(z_flag), .busy(cpu_busy), .done(cpu_done), .halted(cpu_halt)
    );

    // Scheduler runs at 50MHz with a CLOCK ENABLE pulse, no gated clock.
    always @(posedge clk50) begin
        if (rst) begin
            auto_counter <= 24'd0;
            auto_run <= 1'b0;
            display_page <= 2'd0;
            soft_reset <= 1'b0;
            cpu_start <= 1'b0;
        end else begin
            soft_reset <= 1'b0;
            cpu_start <= 1'b0;

            if (display_evt) begin
                if (display_page == 2'd2)
                    display_page <= 2'd0;
                else
                    display_page <= display_page + 2'd1;
            end

            // Priority: KEY2 can restart AFTER program end.
            if (auto_evt) begin
                soft_reset <= 1'b1;
                auto_run <= 1'b1;
                auto_counter <= 24'd0;
            end else if (cpu_halt && !soft_reset) begin
                auto_run <= 1'b0;
                auto_counter <= 24'd0;
            end else if (pause_evt) begin
                auto_run <= ~auto_run;
                auto_counter <= 24'd0;
            end else if (auto_run && !cpu_busy && !soft_reset) begin
                if (auto_counter == AUTO_DIV - 1) begin
                    auto_counter <= 24'd0;
                    cpu_start <= 1'b1;
                end else begin
                    auto_counter <= auto_counter + 24'd1;
                end
            end else begin
                auto_counter <= 24'd0;
            end

            // KEY1 works in manual mode and after KEY3 pauses Auto.
            if (step_evt && !auto_run && !cpu_busy && !cpu_halt && !soft_reset)
                cpu_start <= 1'b1;
        end
    end

    reg [23:0] shown;
    always @(*) begin
        case (display_page)
            2'd0: shown = {pc, r1, r2};
            2'd1: shown = {r3, alu_last, memory_q};
            2'd2: shown = {instruction, 7'b0000000, z_flag};
            default: shown = {pc, r1, r2};
        endcase
    end
    ct5_sevenseg6 #(.SCAN_DIV(SCAN_DIV)) display(
        .clk(clk50), .rst(rst), .value(shown), .dig(dig), .sel(sel));

    // led[3]=program finished, [2]=Auto running,
    // led[1]=Z_FLAG (new), [0]=CPU busy.
    assign led = {cpu_halt, auto_run, z_flag, cpu_busy};
endmodule
