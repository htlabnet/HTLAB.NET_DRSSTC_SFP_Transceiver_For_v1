/*============================================================================*/
/*
 * @file    cdr.v
 * @brief   Oversampling clock data recovery (CDR) module
 * @note    Serial data rate : i_clk / 4
 * @date    2020/11/28
 * @author  kingyo
 */
/*============================================================================*/

module cdr (
    input   wire            i_clk,
    input   wire            i_res_n,

    // Input Serial Data
    input   wire            i_SerialData,

    // Output Recovery Data
    output  reg             o_RecoveryData,
    output  reg             o_DataEn,

    // Error
    output  reg             o_err
);

    // Input data synchronizer
    reg     [2:0]   r_syncFF;
    always @(posedge i_clk or negedge i_res_n) begin
        if (~i_res_n) begin
            r_syncFF <= 3'd0;
        end else begin
            r_syncFF <= {r_syncFF[1:0], i_SerialData};
        end
    end

    // Detect data stream transitions
    wire            w_ts = r_syncFF[2] ^ r_syncFF[1];
    
    // Recovery Logic
    reg     [1:0]   r_rcvState;
    reg             r_ts_old;
    always @(posedge i_clk or negedge i_res_n) begin
        if (~i_res_n) begin
            r_rcvState <= 2'd0;
            o_RecoveryData <= 1'b0;
            o_DataEn <= 1'b0;
            o_err <= 1'b0;
            r_ts_old <= 1'b0;
        end else begin
            r_ts_old <= w_ts;

            // Update transition position
            if (w_ts) begin
                r_rcvState <= 2'd0;

                // Error detect
                if (r_rcvState == 2'd1 || r_ts_old == 1'b1) begin
                    o_err <= 1'b1;
                end

            end else begin
                r_rcvState <= r_rcvState + 2'd1;
                o_err <= 1'b0;
            end

            // Capture data stream
            if (r_rcvState == 2'd1) begin   // 1 or 2
                o_RecoveryData <= r_syncFF[2];
                o_DataEn <= 1'b1;
            end else begin
                o_DataEn <= 1'b0;
            end
        end
    end

endmodule
