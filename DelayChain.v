// DelayChain 모듈: FIR 필터의 40-tap 지연 라인을 구현
// - 입력 데이터를 40단계로 지연시키고, 이를 4개의 MAC 유닛에 분배
// - 각 MAC 유닛은 10개의 탭을 처리
module DelayChain (
    // 시스템 신호
    input               iClk,           // 12MHz 시스템 클럭
    input               iRsn,           // Active low 리셋
    input               iEnDelay,       // 600kHz 샘플링 주기의 지연 라인 활성화 신호
    input               iEnSample600k,  // 추가: 600kHz 샘플링 enable
    input       [2:0]   iFirIn,         // 3비트 FIR 필터 입력 (-3,-1,1,3)

    // MAC 유닛별 지연 출력 (40개 탭을 10개씩 4그룹으로 분할)
    output      [29:0]  oDelay1_10,     // MAC1용: tap 0-9의 데이터 (3bit x 10 = 30bit)
    output      [29:0]  oDelay11_20,    // MAC2용: tap 10-19의 데이터
    output      [29:0]  oDelay21_30,    // MAC3용: tap 20-29의 데이터
    output      [29:0]  oDelay31_40     // MAC4용: tap 30-39의 데이터
);

    // 40단 시프트 레지스터 선언
    // - 각 레지스터는 3비트 데이터를 저장
    // - 40단의 직렬 연결된 지연 라인 구성
    reg [2:0] rShiftReg [0:39];  
    integer i;

    // 시프트 레지스터 동작
    // - 매 클럭마다 데이터를 한 단계씩 시프트
    // - iEnDelay 신호가 활성화될 때만 시프트 동작
    always @(posedge iClk or negedge iRsn) begin
        if (!iRsn) begin
            // 비동기 리셋: 모든 레지스터를 0으로 초기화
            for (i = 0; i < 40; i = i + 1)
                rShiftReg[i] <= 3'b0;
        end
        else if (iEnDelay && iEnSample600k) begin  // 수정: 두 신호 모두 확인
            // 새로운 입력을 첫 번째 레지스터에 저장
            rShiftReg[0] <= iFirIn;
            // 나머지 레지스터들은 이전 단계의 값을 받음
            for (i = 1; i < 40; i = i + 1)
                rShiftReg[i] <= rShiftReg[i-1];
        end
    end

    // 시프트 레지스터의 값을 MAC 유닛별로 그룹화하여 출력
    // - 각 MAC 유닛은 10개의 연속된 탭을 처리
    // - 3비트 데이터 10개를 연결하여 30비트 버스로 출력
    assign oDelay1_10   = {rShiftReg[9],  rShiftReg[8],  rShiftReg[7],  rShiftReg[6],  rShiftReg[5],
                          rShiftReg[4],  rShiftReg[3],  rShiftReg[2],  rShiftReg[1],  rShiftReg[0]};
    
    assign oDelay11_20  = {rShiftReg[19], rShiftReg[18], rShiftReg[17], rShiftReg[16], rShiftReg[15],
                          rShiftReg[14], rShiftReg[13], rShiftReg[12], rShiftReg[11], rShiftReg[10]};
    
    assign oDelay21_30  = {rShiftReg[29], rShiftReg[28], rShiftReg[27], rShiftReg[26], rShiftReg[25],
                          rShiftReg[24], rShiftReg[23], rShiftReg[22], rShiftReg[21], rShiftReg[20]};
    
    assign oDelay31_40  = {rShiftReg[39], rShiftReg[38], rShiftReg[37], rShiftReg[36], rShiftReg[35],
                          rShiftReg[34], rShiftReg[33], rShiftReg[32], rShiftReg[31], rShiftReg[30]};

endmodule