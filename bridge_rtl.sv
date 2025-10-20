`timescale 1ns / 1ps

module bridge_rtl(
    input hclk, hresetn, hselapb, hwrite,
    input [1:0] htrans,
    input [31:0] haddr, hwdata,
    input [31:0] prdata,
    output reg psel, penable, pwrite,
    output reg hresp, hready,
    output reg [31:0] hrdata, paddr, pwdata
);
    
    // State definitions with pipelining support
    parameter IDLE        = 3'b000;
    parameter READ_SETUP  = 3'b001;
    parameter READ_ENABLE = 3'b010;
    parameter WRITE_WAIT  = 3'b011;
    parameter WRITE_SETUP = 3'b100;
    parameter WRITE_ENABLE = 3'b101;
    parameter WRITE_PIPE  = 3'b110;  // Pipelined write state
    
    reg [2:0] present_state, next_state;
    reg [31:0] haddr_temp, hwdata_temp;
    reg valid;
    reg pipe_active;  // Pipeline control flag
    
    // Valid signal generation
    always @(*) begin
        valid = (hselapb == 1'b1) && (htrans == 2'b10 || htrans == 2'b11);
    end
    
    // Sequential state register
    always @(posedge hclk or negedge hresetn) begin
        if (!hresetn) begin
            present_state <= IDLE;
            haddr_temp <= 32'h0;
            hwdata_temp <= 32'h0;
            pipe_active <= 1'b0;
        end else begin
            present_state <= next_state;
            // Buffer address/data for pipelining
            if (valid && hwrite && present_state == WRITE_WAIT) begin
                haddr_temp <= haddr;
                hwdata_temp <= hwdata;
                pipe_active <= 1'b1;
            end else if (present_state == WRITE_ENABLE) begin
                pipe_active <= 1'b0;
            end
        end
    end
    
    // Next state logic and output generation
    always @(*) begin
        // Default outputs
        psel = 1'b0;
        penable = 1'b0;
        pwrite = 1'b0;
        hready = 1'b1;
        hresp = 1'b0;
        hrdata = 32'h0;
        paddr = 32'h0;
        pwdata = 32'h0;
        next_state = present_state;
        
        case (present_state)
            IDLE: begin
                psel = 1'b0;
                penable = 1'b0;
                hready = 1'b1;
                
                if (valid) begin
                    if (hwrite) begin
                        next_state = WRITE_WAIT;
                    end else begin
                        next_state = READ_SETUP;
                    end
                end
            end
            
            READ_SETUP: begin
                psel = 1'b1;
                penable = 1'b0;
                pwrite = 1'b0;
                paddr = haddr;
                hready = 1'b0;  // Extend transfer
                next_state = READ_ENABLE;
            end
            
            READ_ENABLE: begin
                psel = 1'b1;
                penable = 1'b1;
                pwrite = 1'b0;
                paddr = haddr;
                hrdata = prdata;
                
                // Pipelined decision making
                if (valid) begin
                    hready = 1'b1;  // Ready for next transfer
                    if (hwrite) begin
                        next_state = WRITE_WAIT;
                    end else begin
                        next_state = READ_SETUP;
                    end
                end else begin
                    hready = 1'b1;
                    next_state = IDLE;
                end
            end
            
            WRITE_WAIT: begin
                psel = 1'b0;
                penable = 1'b0;
                // Stay ready to accept pipelined writes
                hready = 1'b1;
                next_state = WRITE_SETUP;
            end
            
            WRITE_SETUP: begin
                psel = 1'b1;
                penable = 1'b0;
                pwrite = 1'b1;
                paddr = haddr_temp;
                pwdata = hwdata_temp;
                hready = 1'b0;  // Not ready during APB setup
                
                // Check for pipelined write
                if (pipe_active && valid && hwrite) begin
                    next_state = WRITE_PIPE;
                end else begin
                    next_state = WRITE_ENABLE;
                end
            end
            
            WRITE_ENABLE: begin
                psel = 1'b1;
                penable = 1'b1;
                pwrite = 1'b1;
                paddr = haddr_temp;
                pwdata = hwdata_temp;
                
                if (valid) begin
                    hready = 1'b1;  // Ready for next
                    if (hwrite) begin
                        next_state = WRITE_WAIT;
                    end else begin
                        next_state = READ_SETUP;
                    end
                end else begin
                    hready = 1'b1;
                    next_state = IDLE;
                end
            end
            
            WRITE_PIPE: begin
                psel = 1'b1;
                penable = 1'b1;
                pwrite = 1'b1;
                paddr = haddr_temp;
                pwdata = hwdata_temp;
                hready = 1'b1;  // Ready for next pipelined write
                
                // Immediately start next write setup
                next_state = WRITE_SETUP;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule
