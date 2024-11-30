module FinalSum (
    input               iClk,
    input               iRsn,
    input               iEnDelay,       // 추가: Controller의 oEnDelay 신호
    input               iEnSample600k,  // 추가: 600kHz 샘플링 enable

    input      [15:0]   iMac1,
    input      [15:0]   iMac2,
    input      [15:0]   iMac3,
    input      [15:0]   iMac4,
    output reg [15:0]   oFirOut
);

    reg [17:0] sum_stage1_a, sum_stage1_b;
    reg [18:0] final_sum;

    // First stage: parallel additions
    always @(posedge iClk or negedge iRsn) begin
        if (!iRsn) begin
            sum_stage1_a <= 18'h0;
            sum_stage1_b <= 18'h0;
        end else if (iEnDelay && iEnSample600k) begin  // 수정: 두 신호 모두 확인
            sum_stage1_a <= {iMac1[15], iMac1[15:0]} + {iMac2[15], iMac2[15:0]};
            sum_stage1_b <= {iMac3[15], iMac3[15:0]} + {iMac4[15], iMac4[15:0]};
        end
    end

    // Final stage with saturation
    always @(posedge iClk or negedge iRsn) begin
        if (!iRsn) begin
            oFirOut <= 16'h0;
        end else begin
            final_sum = {sum_stage1_a[17], sum_stage1_a} + {sum_stage1_b[17], sum_stage1_b};
            // Saturation logic
            if (final_sum[18] && !final_sum[17])
                oFirOut <= 16'h8000;  // Negative saturation
            else if (!final_sum[18] && final_sum[17])
                oFirOut <= 16'h7FFF;  // Positive saturation
            else
                oFirOut <= final_sum[16:1];  // Normal case
        end
    end

endmodule
