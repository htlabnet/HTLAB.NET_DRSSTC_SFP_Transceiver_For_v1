/*============================================================================*/
/*
 * @file    serial_rx_master.v
 * @brief   Serial data recieve & decode module for master CPLD
 * @note    Sampling rate    : 40MHz
            Serial data rate : 10Mbps
 * @date    2020/12/05
 * @author  kingyo
 */
/*============================================================================*/

module serial_rx_master (
    input   wire            i_clk,      // 40MHz
    input   wire            i_res_n,

    // Input serial data
    input   wire            i_SerialData,

    // SFP receiver enable
    output  wire            o_rcv_en_n,

    // Output data
    output  reg             o_over_current,
    output  reg     [15:0]  o_rx_data1,
    output  reg     [15:0]  o_rx_data2,

    // Status LED
    output  wire    [1:0]   o_rx_led,

    // Rx Error count
    output  reg     [15:0]  o_err_cnt
);

    assign o_rcv_en_n = 1'b0;   // Always enable

    wire            w_sync1bData;
    wire            w_sync1bEn;
    wire            w_cdr_err;

    // CDR
    cdr cdr_inst (
        .i_clk ( i_clk ),
        .i_res_n ( i_res_n ),
        .i_SerialData ( i_SerialData ),
        .o_RecoveryData ( w_sync1bData ),
        .o_DataEn ( w_sync1bEn ),
        .o_err ( w_cdr_err )
    );

    // 10bit shift register
    reg     [9:0]   r_10bShift;
    always @(posedge i_clk or negedge i_res_n) begin
        if (~i_res_n) begin
            r_10bShift <= 10'd0;
        end else if (w_sync1bEn) begin
            r_10bShift <= {r_10bShift[8:0], w_sync1bData};
        end
    end

    // Detect K28.5 code
    wire            w_k28_5_det = (r_10bShift == 10'b0011111010) | 
                                  (r_10bShift == 10'b1100000101);

    // Symbol lock
    reg     [3:0]   r_sym_bitCnt;
    wire            r_sym_capture = (r_sym_bitCnt == 4'd9);
    reg     [9:0]   r_sym_data;
    always @(posedge i_clk or negedge i_res_n) begin
        if (~i_res_n) begin
            r_sym_bitCnt <= 4'd0;
            r_sym_data <= 10'd0;
        end else if (w_sync1bEn) begin
            if (w_k28_5_det || r_sym_capture) begin
                r_sym_bitCnt <= 4'd0;
            end else begin
                r_sym_bitCnt <= r_sym_bitCnt + 4'd1;
            end

            if (r_sym_capture) begin
                r_sym_data <= r_10bShift;
            end
        end
    end

    // Symbol lock status
    reg             r_sym_locked;
    reg     [15:0]  r_k28_5_cnt;
    reg             r_code_err;
    always @(posedge i_clk or negedge i_res_n) begin
        if (~i_res_n) begin
            r_sym_locked <= 1'b0;
            r_k28_5_cnt <= 16'hFFFF;
        end else if (w_cdr_err | r_code_err) begin
            r_sym_locked <= 1'b0;
        end else if (w_sync1bEn) begin
            if (w_k28_5_det) begin
                r_k28_5_cnt <= 16'd0;
                if (r_k28_5_cnt == 16'h9ff) begin
                    r_sym_locked <= 1'b1;
                end else begin
                    r_sym_locked <= 1'b0;
                end
            end else begin
                if (r_k28_5_cnt != 16'hFFFF) begin
                    r_k28_5_cnt <= r_k28_5_cnt + 16'd1;
                end
            end

            if (r_k28_5_cnt > 16'h9ff) begin
                r_sym_locked <= 1'b0;
            end
        end
    end


    // Dispality & Error control
    wire            w_disp;
    reg             r_disp;
    wire            w_code_err;
    wire            w_disp_err;
    reg             r_disp_err;
    reg             r_sym_locked_old;
    always @(posedge i_clk or negedge i_res_n) begin
        if (~i_res_n) begin
            r_disp <= 1'b0;
            r_code_err <= 1'b1;
            r_disp_err <= 1'b1;
            o_err_cnt <= 16'd0;
            r_sym_locked_old <= 1'b0;
        end else begin
            if (r_sym_capture) begin
                r_disp <= w_disp;
                r_code_err <= w_code_err;
                r_disp_err <= w_disp_err;
            end

            // Error counter
            r_sym_locked_old <= r_sym_locked;
            if (r_sym_locked_old & ~r_sym_locked) begin
                if (o_err_cnt != 16'hFFFF) begin
                    o_err_cnt <= o_err_cnt + 16'd1;
                end
            end
        end
    end

    // 8b10b decode
    wire    [7:0]   w_8b_data;
    decode_8b10b decode_8b10b (
        .datain ( r_sym_data[9:0] ),
        .dispin ( r_disp ),
        .dataout ( w_8b_data[7:0] ),
        .dispout ( w_disp ),
        .code_err ( w_code_err ),
        .disp_err ( w_disp_err )
    );

    reg             r_sym_capture_FF;
    reg             r_k28_5_det_FF;
    wire            w_out_trig = (~r_sym_capture & r_sym_capture_FF);
    always @(posedge i_clk or negedge i_res_n) begin
        if (~i_res_n) begin
            r_sym_capture_FF <= 1'b0;
            r_k28_5_det_FF <= 1'b0;
        end else begin
            r_sym_capture_FF <= r_sym_capture;
            r_k28_5_det_FF <= w_k28_5_det;
        end
    end

    // Parity Check
    wire            w_p1_ok = ^w_8b_data[7:0];

    // Output
    reg     [15:0]  r_rx_data1_buf;
    reg     [15:0]  r_rx_data2_buf;
    reg     [ 3:0]  r_rx_data_cnt;
    reg             r_p1_allok;
    always @(posedge i_clk or negedge i_res_n) begin
        if (~i_res_n) begin
            o_over_current <= 1'b0;
            o_rx_data1 <= 16'd0;
            o_rx_data2 <= 16'd0;
            r_rx_data1_buf <= 16'd0;
            r_rx_data2_buf <= 16'd0;
            r_rx_data_cnt <= 4'd0;
            r_p1_allok <= 1'b1;
        end else if (w_out_trig) begin
            
            // If K28.5
            if (r_k28_5_det_FF) begin
                // When the parity is all OK, update the output data.
                if (r_p1_allok) begin
                    o_rx_data1 <= r_rx_data1_buf;
                    o_rx_data2 <= r_rx_data2_buf;
                end
                r_rx_data_cnt <= 4'd0;
                r_p1_allok <= 1'b1;
            end else begin
                if (w_p1_ok & r_sym_locked) begin

                    // Update Over current status
                    o_over_current <= w_8b_data[7];

                    // Assembling the rx data.
                    case (r_rx_data_cnt[3:0])
                        4'd0 : r_rx_data1_buf[15:12] <= w_8b_data[4:1];
                        4'd1 : r_rx_data1_buf[11: 8] <= w_8b_data[4:1];
                        4'd2 : r_rx_data1_buf[ 7: 4] <= w_8b_data[4:1];
                        4'd3 : r_rx_data1_buf[ 3: 0] <= w_8b_data[4:1];
                        4'd4 : r_rx_data2_buf[15:12] <= w_8b_data[4:1];
                        4'd5 : r_rx_data2_buf[11: 8] <= w_8b_data[4:1];
                        4'd6 : r_rx_data2_buf[ 7: 4] <= w_8b_data[4:1];
                        4'd7 : r_rx_data2_buf[ 3: 0] <= w_8b_data[4:1];
                        default : /* Do nothing */;
                    endcase
                end else begin
                    // Parity error or symbol lock NG.
                    r_p1_allok <= 1'b0;
                end

                if (r_rx_data_cnt != 4'hF) begin
                    r_rx_data_cnt <= r_rx_data_cnt + 4'd1;
                end
            end
        end
    end

    // RX LED
    assign o_rx_led[0] = ~r_sym_locked;     // Red
    assign o_rx_led[1] = o_over_current;    // Green

endmodule
