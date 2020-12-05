/*============================================================================*/
/*
 * @file    uart_tx.v
 * @brief   UART Tx module
 * @note    baud rate : 9600bps
 * @date    2020/11/29
 * @author  kingyo
 */
/*============================================================================*/

module uart_tx (
    input   wire            i_clk,      // 40MHz
    input   wire            i_res_n,
    input   wire            i_tx_en,

    input   wire    [7:0]   i_reg_1,
    input   wire    [7:0]   i_reg_2,
    input   wire    [7:0]   i_reg_3,
    input   wire    [7:0]   i_reg_4,
    input   wire    [7:0]   i_reg_5,
    input   wire    [7:0]   i_reg_6,

    output  wire            o_uart_tx
);
    parameter   size_of_byte = 7'd18;

    // baud rate generator
    reg     [12:0]  r_baud_cnt;
    wire            w_baud_pls = (r_baud_cnt == 13'd4166);
    always @(posedge i_clk or negedge i_res_n) begin
        if (~i_res_n) begin
            r_baud_cnt <= 13'd0;
        end else begin
            if (~i_tx_en) begin
                r_baud_cnt <= 13'd0;
            end else if (w_baud_pls) begin
                r_baud_cnt <= 13'd0;
            end else begin
                r_baud_cnt <= r_baud_cnt + 13'd1;
            end
        end
    end


    // Send UART bit
    wire    [7:0]   w_tx_data;
    reg             r_uart_tx;
    reg     [9:0]   r_tx_shift; // {STOP, DATA[7:0], START}
    always @(posedge i_clk or negedge i_res_n) begin
        if (~i_res_n) begin
            r_uart_tx <= 1'b1;
            r_tx_shift <= 10'd0;
        end else if (~i_tx_en) begin
            r_uart_tx <= 1'b1;
            r_tx_shift <= 10'd0;
        end else if (w_baud_pls) begin
            if (r_tx_shift == 10'd0) begin
                r_uart_tx <= 1'b1;
                r_tx_shift <= {1'b1, w_tx_data[7:0], 1'b0};
            end else begin
                r_uart_tx <= r_tx_shift[0];
                r_tx_shift <= {1'b0, r_tx_shift[9:1]};
            end
        end
    end

    // byte state machine
    reg     [6:0]   r_byte_cnt;
    always @(posedge i_clk or negedge i_res_n) begin
        if (~i_res_n) begin
            r_byte_cnt <= 7'd0;
        end else if (~i_tx_en) begin
            r_byte_cnt <= 7'd0;
        end else if (w_baud_pls & (r_tx_shift == 10'd0)) begin
            r_byte_cnt <= r_byte_cnt + 7'd1;
        end
    end

    // HEX to ASCII code
    function [7:0] getAscii(input [3:0] in);
    begin
        case (in)
        4'h0: getAscii = 8'h30;
        4'h1: getAscii = 8'h31;
        4'h2: getAscii = 8'h32;
        4'h3: getAscii = 8'h33;
        4'h4: getAscii = 8'h34;
        4'h5: getAscii = 8'h35;
        4'h6: getAscii = 8'h36;
        4'h7: getAscii = 8'h37;
        4'h8: getAscii = 8'h38;
        4'h9: getAscii = 8'h39;
        4'hA: getAscii = 8'h41;
        4'hB: getAscii = 8'h42;
        4'hC: getAscii = 8'h43;
        4'hD: getAscii = 8'h44;
        4'hE: getAscii = 8'h45;
        4'hF: getAscii = 8'h46;
        endcase
    end
    endfunction

    // byte data
    assign w_tx_data = (r_byte_cnt == 7'd0 ) ? getAscii(i_reg_1[7:4]) :
                       (r_byte_cnt == 7'd1 ) ? getAscii(i_reg_1[3:0]) :
                       (r_byte_cnt == 7'd2 ) ? 8'h20 :
                       (r_byte_cnt == 7'd3 ) ? getAscii(i_reg_2[7:4]) :
                       (r_byte_cnt == 7'd4 ) ? getAscii(i_reg_2[3:0]) :
                       (r_byte_cnt == 7'd5 ) ? 8'h20 :
                       (r_byte_cnt == 7'd6 ) ? getAscii(i_reg_3[7:4]) :
                       (r_byte_cnt == 7'd7 ) ? getAscii(i_reg_3[3:0]) :
                       (r_byte_cnt == 7'd8 ) ? 8'h20 :
                       (r_byte_cnt == 7'd9 ) ? getAscii(i_reg_4[7:4]) :
                       (r_byte_cnt == 7'd10) ? getAscii(i_reg_4[3:0]) :
                       (r_byte_cnt == 7'd11) ? 8'h20 :
                       (r_byte_cnt == 7'd12) ? getAscii(i_reg_5[7:4]) :
                       (r_byte_cnt == 7'd13) ? getAscii(i_reg_5[3:0]) :
                       (r_byte_cnt == 7'd14) ? 8'h20 :
                       (r_byte_cnt == 7'd15) ? getAscii(i_reg_6[7:4]) :
                       (r_byte_cnt == 7'd16) ? getAscii(i_reg_6[3:0]) :
                       8'h0d;   // CR


    // Enable control
    assign o_uart_tx = (r_byte_cnt < size_of_byte) ? r_uart_tx : 1'b1;


endmodule
