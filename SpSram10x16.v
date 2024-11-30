// SpSram10x16 모듈: FIR 필터 계수를 저장하는 10x16 단일 포트 RAM
// - 10개의 16비트 계수 저장
// - 계수 업데이트와 필터 동작을 위한 읽기/쓰기 기능 제공
module SpSram10x16 (
    // 시스템 신호
    input               iClk,           // 12MHz 시스템 클럭
    input               iRsn,           // Active low 리셋
    input               iCsn,           // Chip select (active low)
    input               iWrn,           // Write enable (active low)
    input       [3:0]   iAddr,          // RAM 주소 (0-9)
    input      [15:0]   iWrDt,          // 쓰기 데이터 (계수 값)
    output reg [15:0]   oRdDt,          // 읽기 데이터 
    output reg [159:0]  oCoeff          // MAC으로 전달되는 계수 (16bit x 10 = 160bit)
);

    // 10x16 RAM 선언 (10개의 16비트 계수 저장)
    reg [15:0] rMem [0:9];
    integer i;

    // Write 동작
    // - Chip select와 Write enable이 모두 활성화된 경우에만 동작
    // - 유효한 주소 범위(0-9)인 경우에만 쓰기 수행
    always @(posedge iClk) begin
        if (!iCsn && !iWrn && iAddr < 4'd10)
            rMem[iAddr] <= iWrDt;
    end

    // Read 동작 및 계수 출력
    // - 리셋시 모든 출력을 0으로 초기화
    // - 읽기 동작시 선택된 주소의 데이터를 출력
    // - 모든 계수를 MAC 유닛으로 동시에 출력
    always @(posedge iClk or negedge iRsn) begin
        if (!iRsn) begin
            oRdDt <= 16'h0;
            oCoeff <= 160'h0;
        end
        else if (!iCsn && iWrn) begin
            // 일반 읽기 동작
            if (iAddr < 4'd10) begin
                oRdDt <= rMem[iAddr];
            end
            
            // 모든 계수를 하나의 버스로 출력
            oCoeff <= {rMem[9], rMem[8], rMem[7], rMem[6], rMem[5],
                      rMem[4], rMem[3], rMem[2], rMem[1], rMem[0]};
        end
    end

endmodule