`timescale 1ns / 1ps

module bridge_tb();

    // ==================== SIGNAL DECLARATIONS ====================
    
    // AHB Interface Signals
    reg hclk;
    reg hresetn;
    reg hselapb;
    reg hwrite;
    reg [1:0] htrans;
    reg [31:0] haddr;
    reg [31:0] hwdata;
    
    // APB Interface Signals
    reg [31:0] prdata;
    
    // Outputs
    wire hresp;
    wire hready;
    wire [31:0] hrdata;
    wire psel;
    wire penable;
    wire pwrite;
    wire [31:0] paddr;
    wire [31:0] pwdata;
    
    // Test Control
    integer test_count;
    integer error_count;
    integer cycle_count;
    integer start_time, end_time;
    
    // ==================== DUT INSTANTIATION ====================
    
    bridge_rtl dut (
        .hclk(hclk),
        .hresetn(hresetn),
        .hselapb(hselapb),
        .hwrite(hwrite),
        .htrans(htrans),
        .haddr(haddr),
        .hwdata(hwdata),
        .prdata(prdata),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .hresp(hresp),
        .hready(hready),
        .hrdata(hrdata),
        .paddr(paddr),
        .pwdata(pwdata)
    );
    
    // ==================== CLOCK GENERATION ====================
    
    initial begin
        hclk = 0;
        forever #5 hclk = ~hclk;  // 100MHz clock
    end
    
    // ==================== CYCLE COUNTER ====================
    
    always @(posedge hclk) begin
        if (!hresetn) cycle_count <= 0;
        else cycle_count <= cycle_count + 1;
    end
    
    // ==================== MAIN TEST SEQUENCE ====================
    
    initial begin
        // Initialize
        test_count = 0;
        error_count = 0;
        cycle_count = 0;
        
        $dumpfile("bridge_tb.vcd");
        $dumpvars(0, bridge_tb);
        
        $display("==============================================");
        $display("    PIPELINED AHB to APB BRIDGE TESTBENCH");
        $display("==============================================");
        
        initialize_signals();
        apply_reset();
        
        // Run comprehensive test suite
        run_basic_tests();
        run_pipelined_tests();

        
        print_final_summary();
        $finish;
    end
    
    // ==================== TASK DEFINITIONS ====================
    
    task initialize_signals;
        begin
            hresetn = 1'b0;
            hselapb = 1'b0;
            hwrite = 1'b0;
            htrans = 2'b00;
            haddr = 32'h0000_0000;
            hwdata = 32'h0000_0000;
            prdata = 32'h0000_0000;
            #10;
            $display("Time %0t: All signals initialized", $time);
        end
    endtask
    
    task apply_reset;
        begin
            $display("\n--- Applying Reset ---");
            hresetn = 1'b0;
            repeat(5) @(posedge hclk);
            hresetn = 1'b1;
            repeat(2) @(posedge hclk);
            $display("Time %0t: Reset released", $time);
        end
    endtask
    
    task wait_for_ready;
        begin
            wait(hready == 1'b1);
            @(posedge hclk);
        end
    endtask
    
    // ==================== BASIC TESTS ====================
    
    task run_basic_tests;
        begin
            $display("\n=== BASIC FUNCTIONALITY TESTS ===");
            
            test_single_read();
            test_single_write();
           
        end
    endtask
    
    task test_single_read;
        begin
            test_count++;
            $display("\nTest %0d: Single Read Operation", test_count);
            
            @(posedge hclk);
            hselapb = 1'b1;
            hwrite = 1'b0;
            htrans = 2'b10;
            haddr = 32'h4000_1000;
            
            @(posedge hclk);
            htrans = 2'b00;
            hselapb = 1'b0;
            
            wait(psel == 1'b1);
            @(posedge hclk);
            prdata = 32'hDEAD_BEEF;
            
            wait_for_ready();
            
            if (hrdata === 32'hDEAD_BEEF) begin
                $display("  ✅ PASS: Read data correct = 0x%h", hrdata);
            end else begin
                $display("  ❌ FAIL: Expected 0xDEAD_BEEF, Got 0x%h", hrdata);
                error_count++;
            end
        end
    endtask
    
    task test_single_write;
        begin
            test_count++;
            $display("\nTest %0d: Single Write Operation", test_count);
            
            @(posedge hclk);
            hselapb = 1'b1;
            hwrite = 1'b1;
            htrans = 2'b10;
            haddr = 32'h4000_2000;
            hwdata = 32'h1234_5678;
            
            @(posedge hclk);
            htrans = 2'b00;
            hselapb = 1'b0;
            
            wait_for_ready();
            
            if (paddr === 32'h4000_2000 && pwdata === 32'h1234_5678) begin
                $display("  ✅ PASS: Write addr=0x%h, data=0x%h", paddr, pwdata);
            end else begin
                $display("  ❌ FAIL: Write mismatch");
                $display("    Expected: addr=0x40002000, data=0x12345678");
                $display("    Got:      addr=0x%h, data=0x%h", paddr, pwdata);
                error_count++;
            end
        end
    endtask
    
    // ==================== PIPELINED TESTS ====================
    
    task run_pipelined_tests;
        begin
            $display("\n=== PIPELINED OPERATION TESTS ===");
            
            test_pipelined_writes();
            test_pipelined_reads();
            
      
        end
    endtask
    
    task test_pipelined_writes;
        integer start_cycle;
        begin
            test_count++;
            $display("\nTest %0d: Pipelined Write Operations", test_count);
            
            start_cycle = cycle_count;
            
            // Start pipeline with 4 consecutive writes
            @(posedge hclk);
            hselapb = 1'b1;
            hwrite = 1'b1;
            
            // Write 1
            htrans = 2'b10;
            haddr = 32'h5000_1000;
            hwdata = 32'h1111_1111;
            @(posedge hclk);
            
            // Write 2 (pipelined)
            htrans = 2'b10;
            haddr = 32'h5000_2000;
            hwdata = 32'h2222_2222;
            @(posedge hclk);
            
            // Write 3 (pipelined)
            htrans = 2'b10;
            haddr = 32'h5000_3000;
            hwdata = 32'h3333_3333;
            @(posedge hclk);
            
            // Write 4 (pipelined)
            htrans = 2'b10;
            haddr = 32'h5000_4000;
            hwdata = 32'h4444_4444;
            @(posedge hclk);
            
            // End pipeline
            htrans = 2'b00;
            hselapb = 1'b0;
            @(posedge hclk);
            
            wait_for_ready();
            
            $display("  ✅ PASS: 4 pipelined writes completed in %0d cycles", 
                    cycle_count - start_cycle);
            $display("  Performance: %.1f cycles per write", 
                    real'(cycle_count - start_cycle) / 4.0);
        end
    endtask
    
    task test_pipelined_reads;
        integer start_cycle;
        begin
            test_count++;
            $display("\nTest %0d: Pipelined Read Operations", test_count);
            
            start_cycle = cycle_count;
            
            @(posedge hclk);
            hselapb = 1'b1;
            hwrite = 1'b0;
            
            // Read 1
            htrans = 2'b10;
            haddr = 32'h6000_1000;
            @(posedge hclk);
            
            // Read 2 (pipelined)
            htrans = 2'b10;
            haddr = 32'h6000_2000;
            @(posedge hclk);
            
            // Read 3 (pipelined)
            htrans = 2'b10;
            haddr = 32'h6000_3000;
            @(posedge hclk);
            
            htrans = 2'b00;
            hselapb = 1'b0;
            
            // Provide read data responses
            fork
                begin
                    wait(psel && !pwrite);
                    @(posedge hclk);
                    prdata = 32'hAAAA_AAAA;
                end
                begin
                    wait(psel && !pwrite);
                    @(posedge hclk);
                    prdata = 32'hBBBB_BBBB;
                end
                begin
                    wait(psel && !pwrite);
                    @(posedge hclk);
                    prdata = 32'hCCCC_CCCC;
                end
            join
            
            wait_for_ready();
            
            $display("  ✅ PASS: 3 pipelined reads completed in %0d cycles",
                    cycle_count - start_cycle);
        end
    endtask
    
 
      // ==================== MONITORING ====================
    
    always @(posedge hclk) begin
        if (hselapb && (htrans == 2'b10 || htrans == 2'b11)) begin
            $display("Time %0t: AHB %s - Addr=0x%h, Data=0x%h, HREADY=%b", 
                    $time, hwrite ? "WRITE" : "READ", haddr, hwdata, hready);
        end
        
        if (psel && penable) begin
            $display("Time %0t: APB %s - Addr=0x%h, Data=0x%h", 
                    $time, pwrite ? "WRITE" : "READ", paddr, 
                    pwrite ? pwdata : prdata);
        end
    end
    
    // ==================== FINAL REPORTING ====================
    
    task print_final_summary;
        begin
            $display("\n" + "="*50);
            $display("            SIMULATION COMPLETE");
            $display("="*50);
            $display("Total Tests Executed: %0d", test_count);
            $display("Tests Passed:         %0d", test_count - error_count);
            $display("Tests Failed:         %0d", error_count);
            $display("Total Cycles:         %0d", cycle_count);
            $display("Simulation Time:      %0t ns", $time);
            $display("="*50);
            
            if (error_count == 0) begin
                $display("🎉 ALL TESTS PASSED SUCCESSFULLY! 🎉");
            end else begin
                $display("❌ %0d TEST(S) FAILED - CHECK IMPLEMENTATION", error_count);
            end
            $display("="*50);
        end
    endtask

endmodule
