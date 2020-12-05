/*============================================================================*/
/*
 * @file    drsstc_sfp_transceiver_top.v
 * @brief   drsstc_sfp_transceiver top module
 * @note    http://htlab.net/
 * @date    2019/04/05
 * @author  pcjpnet
 */
/*============================================================================*/

//`define DEF_MASTER_CPLD

module drsstc_sfp_transceiver_top (
    /* Master Clock and Reset */
    input   [1:0]   CLK_40M,
    input   [1:0]   RST_N,
    
    /* 5V-TTL GPIO */
    input   [7:0]   IN,
    output  [7:0]   OUT,
    
    /* 3.3V-TTL GPIO */
    input   [2:0]   LV_IN,
    output  [2:0]   LV_OUT,
    
    /* Onboard DIP-SW */
    input   [7:0]   DIP_SW1,
    input   [7:0]   DIP_SW2,
    
    /* TX and RX LED */
    output  [1:0]   LED_TX,
    output  [1:0]   LED_RX,
    
    /* SFP Module */
    input           SFP_LOSS_SIG,   // If high, received optical power is below the worst-case receiver sensitivity. Low is normal operation.
    output          SFP_RATE_SEL,   // Low:Reduced Bandwidth / High:Full Bandwidth
    output          SFP_TX_DIS_N,   // Tx disable. If high, transmitter disable.
    input           SFP_TX_FLT,     // If high, transmitter Fault. Low is normal operation.
    
    /* SFP MOD_DEF */
    inout   [2:0]   SFP_MOD_DEF,    // Two wire serial interface for serial ID.
    
    /* LVDS I/F IC */
    input           LVDS_DAT_OUT,   // Received Data in.
    output          LVDS_DAT_IN,    // Transmitter Data out.
    output          LVDS_DRV_EN,    // Driver Enable
    output          LVDS_RCV_EN_N,  // Receiver Enable(Active Low)
    
    /* Debug */
    output          TP1,
    output          TP2
    );

    //==================================================================
    // wire
    //==================================================================
    wire            w_clk = CLK_40M[0];
    wire            w_boot_done;
    wire    [1:0]   w_rx_led;
    wire    [1:0]   w_tx_led;
    wire    [15:0]  w_rx_err_cnt;

    // for slave CPLD
    wire    [15:0]  w_slv_tx_data1;
    wire    [15:0]  w_slv_tx_data2;

    // for master CPLD
    wire            w_master_rx_over_current;
    wire    [15:0]  w_master_rx_data1;
    wire    [15:0]  w_master_rx_data2;
    
    //==================================================================
    // Reset
    //==================================================================
    wire            w_rst_n;
    reset_gen reset_gen_inst (
        .i_clk ( w_clk ),
        .i_res_n ( RST_N[0] ),
        .o_res_n ( w_rst_n )
    );

    //==================================================================
    // Boot (reset) sequence
    //==================================================================
    boot_seq boot_seq_inst (
        .i_clk ( w_clk ),
        .i_res_n ( w_rst_n ),
        .o_boot_done ( w_boot_done ),
        .i_rx_led ( w_rx_led[1:0] ),
        .i_tx_led ( w_tx_led[1:0] ),
        .o_rx_led ( LED_RX[1:0] ),
        .o_tx_led ( LED_TX[1:0] )
    );

    //==================================================================
    // Test counter for slave debug
    //==================================================================
`ifndef DEF_MASTER_CPLD
    test_counter test_counter_inst (
        .i_clk ( w_clk ),
        .i_res_n ( w_rst_n ),
        .i_cnt_en ( w_boot_done ),
        .i_cnt_res ( ~w_boot_done ),
        .o_cnt ( w_slv_tx_data2 )
    );
`endif

    //==================================================================
    // Serial data Transmitter
    //==================================================================
`ifdef DEF_MASTER_CPLD
    serial_tx_master serial_tx_master_inst (
        .i_clk ( w_clk ),
        .i_res_n ( w_rst_n ),
        .i_sfp_tx_flt ( SFP_TX_FLT ),
        .i_RawPls ( IN[0] ),
        .i_tx_data1 ( 16'd0 ),
        .i_tx_data2 ( 16'd0 ),
        .o_SerialData ( LVDS_DAT_IN ),
        .o_drv_en ( LVDS_DRV_EN ),
        .o_sfp_tx_dis_n ( SFP_TX_DIS_N ),
        .o_tx_led ( w_tx_led[1:0] )
    );
`else
    assign w_slv_tx_data1 = w_rx_err_cnt;
    serial_tx_slave serial_tx_slave_inst (
        .i_clk ( w_clk ),
        .i_res_n ( w_rst_n ),
        .i_sfp_tx_flt ( SFP_TX_FLT ),
        .i_over_current ( IN[0] ),
        .i_tx_data1 ( w_slv_tx_data1[15:0] ),
        .i_tx_data2 ( w_slv_tx_data2[15:0] ),
        .o_SerialData ( LVDS_DAT_IN ),
        .o_drv_en ( LVDS_DRV_EN ),
        .o_sfp_tx_dis_n ( SFP_TX_DIS_N ),
        .o_tx_led ( w_tx_led[1:0] )
    );
`endif

    //==================================================================
    // Serial data receiver
    //==================================================================
`ifdef DEF_MASTER_CPLD
    serial_rx_master serial_rx_master_inst (
        .i_clk ( w_clk ),
        .i_res_n ( w_rst_n ),
        .i_SerialData ( LVDS_DAT_OUT ),
        .o_rcv_en_n ( LVDS_RCV_EN_N ),
        .o_over_current ( OUT[0] ),
        .o_rx_data1 ( w_master_rx_data1 ),
        .o_rx_data2 ( w_master_rx_data2 ),
        .o_rx_led ( w_rx_led[1:0] ),
        .o_err_cnt ( w_rx_err_cnt[15:0] )
    );
`else
    serial_rx_slave serial_rx_slave_inst (
        .i_clk ( w_clk ),
        .i_res_n ( w_rst_n ),
        .i_SerialData ( LVDS_DAT_OUT ),
        .o_rcv_en_n ( LVDS_RCV_EN_N ),
        .o_RawPls ( OUT[0] ),
        .o_rx_data1 ( w_master_rx_data1 ),
        .o_rx_data2 ( w_master_rx_data2 ),
        .o_rx_led ( w_rx_led[1:0] ),
        .o_err_cnt ( w_rx_err_cnt[15:0] )
    );
`endif

    //==================================================================
    // UART Tx for Debug (Master Only)
    //==================================================================
`ifdef DEF_MASTER_CPLD
    uart_tx uart_tx_inst (
        .i_clk ( w_clk ),
        .i_res_n ( w_rst_n ),
        .i_tx_en ( w_boot_done ),
        .i_reg_1 ( w_rx_err_cnt[15:8] ),
        .i_reg_2 ( w_rx_err_cnt[7:0] ),
        .i_reg_3 ( w_master_rx_data1[15:8] ),
        .i_reg_4 ( w_master_rx_data1[7:0] ),
        .i_reg_5 ( w_master_rx_data2[15:8] ),
        .i_reg_6 ( w_master_rx_data2[7:0] ),
        .o_uart_tx ( OUT[1] )   // TTL_OUT2
    );
`else
    assign OUT[1] = 1'b0;
`endif

    // TODO
    assign OUT[7:2] = 6'd0;
    assign LV_OUT[2:0] = 3'd0;
    assign TP1 = 1'b0;
    assign TP2 = 1'b0;
    assign SFP_RATE_SEL = 1'b0;
    assign SFP_MOD_DEF = 3'bzzz;
    
endmodule
