/*============================================================================*/
/*
 * @file    test_counter.v
 * @brief   Test counter for slave CPLD
 * @note    
 * @date    2020/12/05
 * @author  kingyo
 */
/*============================================================================*/

module test_counter (
    input   wire            i_clk,
    input   wire            i_res_n,

    input   wire            i_cnt_en,
    input   wire            i_cnt_res,
    output  reg     [15:0]  o_cnt
);

    reg     [25:0]  r_prsc;
    wire            w_prsc_max = (r_prsc == 26'd39999999);
    always @(posedge i_clk or negedge i_res_n) begin
        if (~i_res_n) begin
            r_prsc <= 26'd0;
            o_cnt <= 16'd0;
        end else begin
            if (i_cnt_res) begin
                r_prsc <= 26'd0;
                o_cnt <= 16'd0;
            end else if (i_cnt_en) begin
                if (w_prsc_max) begin
                    r_prsc <= 26'd0;
                    o_cnt <= o_cnt + 16'd1;
                end else begin
                    r_prsc <= r_prsc + 26'd1;
                end
            end
        end
    end

endmodule
