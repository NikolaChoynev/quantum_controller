module tb_simple_and;

    logic a;
    logic b;
    logic y;

    simple_and dut (
        .a(a),
        .b(b),
        .y(y)
    );

    initial begin
        a = 0; b = 0; #1;
        $display("a=%0b b=%0b y=%0b", a, b, y);

        a = 0; b = 1; #1;
        $display("a=%0b b=%0b y=%0b", a, b, y);

        a = 1; b = 0; #1;
        $display("a=%0b b=%0b y=%0b", a, b, y);

        a = 1; b = 1; #1;
        $display("a=%0b b=%0b y=%0b", a, b, y);

        $finish;
    end

endmodule