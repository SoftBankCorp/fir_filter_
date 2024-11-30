// MacUnit 모듈: FIR 필터의 곱셈-누산 연산을 수행
// - 10개의 지연된 입력과 해당 계수를 곱하고 누산
// - 3단계 파이프라인: 곱셈 -> 덧셈 -> 누산
module MacUnit (
    // 제어 신호
    input               iEnMul,         // 곱셈 활성화
    input               iEnAdd,         // 덧셈 활성화
    input               iEnAcc,         // 누산 활성화
    
    // 데이터 입력
    input      [29:0]   iDelay,         // 지연된 입력 데이터 (3bit x 10 = 30bit)
    input      [159:0]  iCoeff,         // 계수 데이터 (16bit x 10 = 160bit)
    output     [15:0]   oMacResult      // MAC 연산 결과
);

    // 내부 신호
    wire [15:0] wMulResult [0:9];       // 곱셈 결과
    wire [15:0] wAddResult;             // 덧셈 결과
    reg  [15:0] rMacResult;             // MAC 결과
    
    // 입력 데이터와 계수 분리
    wire [2:0] wDelay [0:9];
    wire [15:0] wCoeff [0:9];
    
    // 입력 버스 분리
    generate
        genvar j;
        for (j = 0; j < 10; j = j + 1) begin : signal_split
            assign wDelay[j] = iDelay[29-j*3 -: 3];
            assign wCoeff[j] = iCoeff[159-j*16 -: 16];
        end
    endgenerate

    // 곱셈 단계 (조합논리)
    generate
        genvar k;
        for (k = 0; k < 10; k = k + 1) begin : mul_stage
            assign wMulResult[k] = {{13{wDelay[k][2]}}, wDelay[k]} * wCoeff[k];
        end
    endgenerate

    // 덧셈 단계 (조합논리)
    assign wAddResult = wMulResult[0] + wMulResult[1] + wMulResult[2] + 
                       wMulResult[3] + wMulResult[4] + wMulResult[5] + 
                       wMulResult[6] + wMulResult[7] + wMulResult[8] + 
                       wMulResult[9];

    // 최종 출력 선택 (조합논리)
    assign oMacResult = (iEnMul && iEnAdd && iEnAcc) ? wAddResult : 16'h0;

endmodule