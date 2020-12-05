/*============================================================================*/
/*
 * @file    boot_seq.v
 * @brief   LED control when power up
 * @note    
 * @date    2020/11/29
 * @author  kingyo
 */
/*============================================================================*/

module boot_seq (
    input   wire            i_clk,
    input   wire            i_res_n,
    output  wire            o_boot_done,

    input   wire    [1:0]   i_rx_led,
    input   wire    [1:0]   i_tx_led,

    output  wire    [1:0]   o_rx_led,
    output  wire    [1:0]   o_tx_led
);

    reg     [25:0]  r_cnt;
    reg     [ 1:0]  r_boot_st;
    wire            w_cnt_max = (r_cnt == 26'd39999999);
    wire            w_boot_done = (r_boot_st == 2'd2);
    always @(posedge i_clk or negedge i_res_n) begin
        if (~i_res_n) begin
            r_cnt <= 26'd0;
            r_boot_st <= 2'd0;
        end else begin
            if (w_cnt_max) begin
                r_cnt <= 26'd0;
                if (~w_boot_done) begin
                    r_boot_st <= r_boot_st + 2'd1;
                end
            end else begin
                r_cnt <= r_cnt + 26'd1;
            end
        end
    end

    assign o_rx_led = (r_boot_st == 2'd0) ? 2'b11 :
                      (r_boot_st == 2'd1) ? 2'b00 :
                      i_rx_led;

    assign o_tx_led = (r_boot_st == 2'd0) ? 2'b11 :
                      (r_boot_st == 2'd1) ? 2'b00 :
                      i_tx_led;

    assign o_boot_done = w_boot_done;
                     
endmodule
