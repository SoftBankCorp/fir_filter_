// Controller 모듈: FIR 필터의 전체 동작을 제어하는 FSM
// - 계수 업데이트와 필터 동작 모드 제어
// - RAM 접근과 MAC 연산 타이밍 제어
// - 600kHz 샘플링 레이트 생성
module Controller (
    // 시스템 신호
    input               iClk12M,        // 12MHz 시스템 클럭
    input               iRsn,           // Active low 리셋
    input               iEnSample600k,  // 600kHz 샘플링 활성화
    input               iCoeffUpdateFlag,// 계수 업데이트 모드 플래그
    input       [5:0]   iNumOfCoeff,    // 계수 개수 설정 (최대 40)
    input       [5:0]   iAddrRam,       // RAM 주소 입력
    
    // RAM 제어 신호
    output reg  [3:0]   oCsnRam,        // RAM Chip select (active low)
    output reg  [3:0]   oWrnRam,        // RAM Write enable (active low)
    output reg  [15:0]  oAddrRam,       // RAM 주소 (4x4bit = 16bit)
    
    // Datapath 제어 신호
    output reg          oEnDelay,       // 지연 라인 활성화
    output reg  [3:0]   oEnMul,         // MAC 곱셈 활성화
    output reg  [3:0]   oEnAdd,         // MAC 덧셈 활성화
    output reg  [3:0]   oEnAcc          // MAC 누산 활성화
);

    // FSM 상태 정의
    parameter IDLE         = 2'b00;      // 초기 상태
    parameter COEFF_UPDATE = 2'b01;      // 계수 업데이트 state
    parameter FILTER_OP    = 2'b10;      // 필터 동작 state

    // 내부 레지스터
    reg [1:0] current_state, next_state; // FSM 상태 레지스터
    reg [5:0] rCoeffCnt;                // 계수 카운터
    reg [5:0] rSampleCnt;               // 샘플링 카운터 (64개 단위)

    // 상태 전이 로직
    always @(posedge iClk12M or negedge iRsn) begin
        if (!iRsn)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    // 다음 상태 결정 로직
    always @(*) begin
        case (current_state)
            IDLE: begin
                next_state = iCoeffUpdateFlag ? COEFF_UPDATE : FILTER_OP;
            end
            COEFF_UPDATE: begin
                next_state = (rCoeffCnt >= iNumOfCoeff) ? FILTER_OP : COEFF_UPDATE;
            end
            FILTER_OP: begin
                next_state = iCoeffUpdateFlag ? COEFF_UPDATE : FILTER_OP;
            end
            default: next_state = IDLE;
        endcase
    end

    // 계수 카운터 제어
    always @(posedge iClk12M or negedge iRsn) begin
        if (!iRsn)
            rCoeffCnt <= 6'h0;
        else if (current_state == COEFF_UPDATE)
            rCoeffCnt <= (rCoeffCnt >= iNumOfCoeff) ? 6'h0 : rCoeffCnt + 1'b1;
        else
            rCoeffCnt <= 6'h0;
    end

    // 제어 신호 생성
    always @(posedge iClk12M or negedge iRsn) begin
        if (!iRsn) begin
            // 리셋시 모든 제어 신호 비활성화
            oCsnRam <= 4'hF;
            oWrnRam <= 4'hF;
            oAddrRam <= 16'h0;
            oEnDelay <= 1'b0;
            oEnMul <= 4'h0;
            oEnAdd <= 4'h0;
            oEnAcc <= 4'h0;
        end
        else begin
            case (current_state)
                COEFF_UPDATE: begin
                    // 계수 업데이트 모드
                    oCsnRam <= 4'h0;     // 모든 RAM 활성화
                    oWrnRam <= 4'h0;     // 쓰기 모드
                    oAddrRam <= {4{iAddrRam[3:0]}};  // 동일 주소를 모든 RAM에 적용
                    oEnDelay <= 1'b0;    // 지연 라인 비활성화
                    oEnMul <= 4'h0;      // MAC 연산 비활성화
                    oEnAdd <= 4'h0;
                    oEnAcc <= 4'h0;
                end
                FILTER_OP: begin
                    // 필터 동작 모드
                    oCsnRam <= 4'h0;     // RAM 읽기 모드
                    oWrnRam <= 4'hF;     // 쓰기 비활성화
                    oAddrRam <= {4{rCoeffCnt[3:0]}};
                    oEnDelay <= iEnSample600k;
                    oEnMul <= {4{iEnSample600k}};
                    oEnAdd <= {4{iEnSample600k}};
                    oEnAcc <= {4{iEnSample600k}};
                end
                default: begin
                    // 초기 상태
                    oCsnRam <= 4'hF;
                    oWrnRam <= 4'hF;
                    oAddrRam <= 16'h0;
                    oEnDelay <= 1'b0;
                    oEnMul <= 4'h0;
                    oEnAdd <= 4'h0;
                    oEnAcc <= 4'h0;
                end
            endcase
        end
    end

endmodule