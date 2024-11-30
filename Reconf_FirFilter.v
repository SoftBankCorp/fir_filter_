// ReConf_FirFilter 모듈: 재구성 가능한 40-tap FIR 필터 최상위 모듈
// - 4개의 RAM에 계수를 분산 저장
// - 40-tap 지연 라인을 4개의 MAC 유닛으로 병렬 처리
// - 600kHz 샘플링 레이트로 동작
module ReConf_FirFilter (
    // 시스템 신호
    input               iClk12M,         // 12MHz 시스템 클럭
    input               iRsn,            // Active low 리셋
    input               iEnSample600k,   // 600kHz 샘플링 enable
    input               iCoeffUpdateFlag, // 계수 업데이트 모드 플래그
    input       [2:0]   iFirIn,          // FIR 필터 입력 (-3,-1,1,3)
    input       [5:0]   iNumOfCoeff,     // 계수 개수 (최대 40)
    input       [5:0]   iAddrRam,        // RAM 주소
    input      [15:0]   iWrDtRam,        // RAM 쓰기 데이터
    output     [15:0]   oFirOut          // FIR 필터 최종 출력
);

    // RAM 제어 신호
    wire [3:0]  wCsnRam;                 // RAM chip select
    wire [3:0]  wWrnRam;                 // RAM write enable
    wire [15:0] wAddrRam;                // RAM 주소 (4개 RAM)
    wire [15:0] wRdDtRam [0:3];          // RAM 읽기 데이터
    wire [159:0] wCoeff [0:3];           // RAM에서 MAC으로 가는 계수 (16bit x 10)

    // MAC 제어 신호
    wire [3:0]  wEnMul;                  // 곱셈 활성화
    wire [3:0]  wEnAdd;                  // 덧셈 활성화
    wire [3:0]  wEnAcc;                  // 누산 활성화
    wire        wEnDelay;                // 지연 라인 활성화

    // Delay chain 신호
    wire [29:0] wDelay1_10;              // MAC1용 지연 데이터 (3bit x 10)
    wire [29:0] wDelay11_20;             // MAC2용 지연 데이터
    wire [29:0] wDelay21_30;             // MAC3용 지연 데이터
    wire [29:0] wDelay31_40;             // MAC4용 지연 데이터
    
    // MAC 결과 신호       
    wire [15:0] wMac1;                   // MAC1 연산 결과
    wire [15:0] wMac2;                   // MAC2 연산 결과
    wire [15:0] wMac3;                   // MAC3 연산 결과
    wire [15:0] wMac4;                   // MAC4 연산 결과

    // Controller 인스턴스
    Controller controller_inst (
        .iClk12M(iClk12M),
        .iRsn(iRsn),
        .iEnSample600k(iEnSample600k),
        .iCoeffUpdateFlag(iCoeffUpdateFlag),
        .iNumOfCoeff(iNumOfCoeff),
        .iAddrRam(iAddrRam),
        .oCsnRam(wCsnRam),
        .oWrnRam(wWrnRam),
        .oAddrRam(wAddrRam),
        .oEnDelay(wEnDelay),
        .oEnMul(wEnMul),
        .oEnAdd(wEnAdd),
        .oEnAcc(wEnAcc)
    );

    // RAM 인스턴스 (4개)
    generate
        genvar i;
        for (i = 0; i < 4; i = i + 1) begin : ram_inst
            SpSram10x16 ram (
                .iClk(iClk12M),
                .iRsn(iRsn),
                .iCsn(wCsnRam[i]),
                .iWrn(wWrnRam[i]),
                .iAddr(wAddrRam[4*i+3 : 4*i]),
                .iWrDt(iWrDtRam),
                .oRdDt(wRdDtRam[i]),
                .oCoeff(wCoeff[i])        // 계수 출력 연결
            );
        end
    endgenerate

    // 지연 체인 인스턴스
    DelayChain delay_chain_inst (
        .iClk(iClk12M),
        .iRsn(iRsn),
        .iEnDelay(wEnDelay),
        .iEnSample600k(iEnSample600k),  // 추가: 600kHz 샘플링 신호 직접 연결
        .iFirIn(iFirIn),
        .oDelay1_10(wDelay1_10),
        .oDelay11_20(wDelay11_20),
        .oDelay21_30(wDelay21_30),
        .oDelay31_40(wDelay31_40)
    );

    // MAC 유닛 인스턴스 (4개)
    // MAC1: tap 0-9 처리
    MacUnit mac1_inst (
        .iClk(iClk12M),
        .iRsn(iRsn),
        .iEnMul(wEnMul[0]),
        .iEnAdd(wEnAdd[0]),
        .iEnAcc(wEnAcc[0]),
        .iDelay(wDelay1_10),
        .iCoeff(wCoeff[0]),
        .oMacResult(wMac1)
    );

    // MAC2: tap 10-19 처리
    MacUnit mac2_inst (
        .iClk(iClk12M),
        .iRsn(iRsn),
        .iEnMul(wEnMul[1]),
        .iEnAdd(wEnAdd[1]),
        .iEnAcc(wEnAcc[1]),
        .iDelay(wDelay11_20),
        .iCoeff(wCoeff[1]),
        .oMacResult(wMac2)
    );

    // MAC3: tap 20-29 처리
    MacUnit mac3_inst (
        .iClk(iClk12M),
        .iRsn(iRsn),
        .iEnMul(wEnMul[2]),
        .iEnAdd(wEnAdd[2]),
        .iEnAcc(wEnAcc[2]),
        .iDelay(wDelay21_30),
        .iCoeff(wCoeff[2]),
        .oMacResult(wMac3)
    );

    // MAC4: tap 30-39 처리
    MacUnit mac4_inst (
        .iClk(iClk12M),
        .iRsn(iRsn),
        .iEnMul(wEnMul[3]),
        .iEnAdd(wEnAdd[3]),
        .iEnAcc(wEnAcc[3]),
        .iDelay(wDelay31_40),
        .iCoeff(wCoeff[3]),
        .oMacResult(wMac4)
    );

    // 최종 합산 모듈 인스턴스
    FinalSum final_sum_inst (
        .iClk(iClk12M),
        .iRsn(iRsn),
        .iEnDelay(wEnDelay),    // Controller의 oEnDelay 신호 연결
        .iEnSample600k(iEnSample600k),  // 추가: 600kHz 샘플링 신호 직접 연결
        .iMac1(wMac1),
        .iMac2(wMac2),
        .iMac3(wMac3),
        .iMac4(wMac4),
        .oFirOut(oFirOut)
    );

endmodule