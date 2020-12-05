/*============================================================================*/
/*
 * @file    tb_top.v
 * @brief   Test bench top module
 * @note    
 * @date    2020/11/18
 * @author  kingyo
 */
/*============================================================================*/
`timescale 1ns / 100ps

module tb_top ();
    parameter MCO_HZ = 40000000;    // 40MHz

    reg             mco = 1'b0;
    reg             jclk = 1'b0;
    reg             res_n;
    wire    [7:0]   w_5v_ttl_in;
    wire    [7:0]   w_5v_ttl_out;
    reg     [2:0]   r_3v3_ttl;
    wire    [2:0]   w_3v3_ttl;
    reg     [7:0]   r_dip_sw1;
    reg     [7:0]   r_dip_sw2;
    wire    [1:0]   w_led_tx;
    wire    [1:0]   w_led_rx;
    reg             r_sfp_loss_sig;
    wire            w_sfp_rate_sel;
    wire            w_sfp_tx_dis_n;
    reg             r_sfp_tx_flt;
    wire    [2:0]   w_sfp_mod_def;
    reg             r_lvds_dat_out;
    wire            w_lvds_dat_in;
    wire            w_lvds_drv_en;
    wire            w_lvds_rcv_en_n;
    wire            w_tp1;
    wire            w_tp2;


    //==================================================================
    // Clock
    //==================================================================
    always #(500000000 / MCO_HZ) mco <= ~mco;

    //==================================================================
    // Reset
    //==================================================================
    initial begin
        res_n = 1'b0;
        #1000;
        res_n = 1'b1;
    end

    //==================================================================
    // 3.3V-TTL GPIO Signal Setting
    //==================================================================
    initial begin
        // All Low
        r_3v3_ttl <= 3'b000;
    end

    //==================================================================
    // DIP SW Setting
    //==================================================================
    initial begin
        // All OFF position
        r_dip_sw1 <= 8'b11111111;
        r_dip_sw2 <= 8'b11111111;
    end

    //==================================================================
    // SFP Module Setting
    //==================================================================
    initial begin
        r_sfp_loss_sig <= 1'b1;
        r_sfp_tx_flt <= 1'b1;
        #10000
        r_sfp_loss_sig <= 1'b0;
        r_sfp_tx_flt <= 1'b0;
    end

    //==================================================================
    // LVDS I/F IC Setting
    //==================================================================
    initial begin
        r_lvds_dat_out <= 1'b0;
    end

    //==================================================================
    // Loop back test
    //==================================================================
    parameter jitter = 2;
    reg     [31:0]  r_dummy_err_cnt = 32'd0;
    // 異常ステート再現
    wire            w_dummy_err_inv  = (r_dummy_err_cnt == 32'd50011);   // 1bit反転
    wire            w_dummy_err_high = (r_dummy_err_cnt >= 32'd100000 && r_dummy_err_cnt <= 32'd120000);    // High固定
    wire            w_dummy_err_low  = (r_dummy_err_cnt >= 32'd200000 && r_dummy_err_cnt <= 32'd220000);    // Low固定
    always @(posedge mco) begin
        r_dummy_err_cnt <= r_dummy_err_cnt + 32'd1;
    end
    always #(500000000 / MCO_HZ + $random %(jitter)) jclk <= ~jclk; 
    always @(posedge mco) begin
        // 擬似的にノイズ混入
        if (w_dummy_err_inv) begin
            r_lvds_dat_out <= ~w_lvds_dat_in;
        end else if (w_dummy_err_high) begin
            r_lvds_dat_out <= 1'b1;
        end else if (w_dummy_err_low) begin
            r_lvds_dat_out <= 1'b0;
        end else begin
            r_lvds_dat_out <= w_lvds_dat_in;
        end
    end


    //==================================================================
    // Dummy input data
    //==================================================================
    tb_pattern_gen pattern_gen (
        .i_clk ( mco ),
        .i_res_n ( res_n ),
        .o_ptn ( w_5v_ttl_in[7:0] )
    );


    //==================================================================
    // DUT
    //==================================================================
    drsstc_sfp_transceiver_top dut (
        /* Master Clock and Reset */
        .CLK_40M ( {mco, mco} ),
        .RST_N ( {res_n, res_n} ),

        /* 5V-TTL GPIO */
        .IN ( w_5v_ttl_in[7:0] ),
        .OUT ( w_5v_ttl_out[7:0] ),
        
        /* 3.3V-TTL GPIO */
        .LV_IN ( r_3v3_ttl[2:0] ),
        .LV_OUT ( w_3v3_ttl[2:0] ),
        
        /* Onboard DIP-SW */
        .DIP_SW1 ( r_dip_sw1[7:0] ),
        .DIP_SW2 ( r_dip_sw2[7:0] ),
        
        /* TX and RX LED */
        .LED_TX ( w_led_tx[1:0] ),
        .LED_RX ( w_led_rx[1:0] ),

        /* SFP Module */
        .SFP_LOSS_SIG ( r_sfp_loss_sig ),
        .SFP_RATE_SEL ( w_sfp_rate_sel ),
        .SFP_TX_DIS_N ( w_sfp_tx_dis_n ),
        .SFP_TX_FLT ( r_sfp_tx_flt ),
        
        /* SFP MOD_DEF */
        .SFP_MOD_DEF ( w_sfp_mod_def[2:0] ),
        
        /* LVDS I/F IC */
        .LVDS_DAT_OUT ( r_lvds_dat_out ),
        .LVDS_DAT_IN ( w_lvds_dat_in ),
        .LVDS_DRV_EN ( w_lvds_drv_en ),
        .LVDS_RCV_EN_N ( w_lvds_rcv_en_n ),

        /* Debug */
        .TP1 ( w_tp1 ),
        .TP2 ( w_tp2 )
    );

endmodule
