`timescale 1ns/10ps

module tb_fir_filter;

    // Clock and reset signals
    reg         iClk12M;
    reg         iRsn;
    reg         iEnSample600k;
    reg         iCoeffUpdateFlag;
    reg  [5:0]  iNumOfCoeff;
    reg  [5:0]  iAddrRam;
    reg  [2:0]  iFirIn;
    reg  [15:0] iWrDtRam;         // RAM 쓰기 데이터 추가
    wire [15:0] oFirOut;          // 필터 출력
    
    // Test output signals (모니터링용)
    wire [3:0]  oCsnRam;
    wire [3:0]  oWrnRam;
    wire [3:0]  oAddrRam [0:3];
    wire        oEnDelay;
    wire [3:0]  oEnMul;
    wire [3:0]  oEnAdd;
    wire [3:0]  oEnAcc;

    // FIR 필터 인스턴스
    ReConf_FirFilter u_fir (
        .iClk12M(iClk12M),
        .iRsn(iRsn),
        .iEnSample600k(iEnSample600k),
        .iCoeffUpdateFlag(iCoeffUpdateFlag),
        .iFirIn(iFirIn),
        .iNumOfCoeff(iNumOfCoeff),
        .iAddrRam(iAddrRam),
        .iWrDtRam(iWrDtRam),
        .oFirOut(oFirOut)
    );

    // Clock generation (12MHz)
    initial begin
        iClk12M = 0;
        forever #41.67 iClk12M = ~iClk12M;
    end

    // 600kHz 샘플링 클럭 생성
    reg [4:0] clk_div;
    always @(posedge iClk12M or negedge iRsn) begin
        if (!iRsn)
            clk_div <= 5'h0;
        else
            clk_div <= clk_div + 1'b1;
    end
    
    always @(posedge iClk12M)
        iEnSample600k <= (clk_div == 5'h0);

    // 테스트 시나리오
    integer i;
    reg [5:0] sample_cnt;
    
    initial begin
        // 초기화
        iRsn = 0;
        iCoeffUpdateFlag = 0;
        iNumOfCoeff = 6'h28;  // 40 coefficients
        iAddrRam = 6'h0;
        iFirIn = 3'b0;
        iWrDtRam = 16'h0;
        sample_cnt = 6'h0;

        // 리셋 해제
        #100 iRsn = 1;
        
        // 계수 업데이트
        #200;
        iCoeffUpdateFlag = 1;
        
        // 40개 계수 쓰기
        for(i=0; i<40; i=i+1) begin
            @(posedge iClk12M);
            iAddrRam = i;
            iWrDtRam = i+1;    // 테스트용 계수값
        end
        
        #100 iCoeffUpdateFlag = 0;

        // 필터 동작 테스트
        #200;
        
        // 64개 단위 입력 패턴 생성
        repeat(10) begin  // 10개의 64샘플 그룹 테스트
            for(i=0; i<64; i=i+1) begin
                @(posedge iClk12M);
                if(i == 0)
                    iFirIn = 3'b001;  // 임펄스 입력
                else
                    iFirIn = 3'b000;  // 일반 입력
            end
        end

        // 시뮬레이션 종료
        #1000 $finish;
    end

    // 결과 모니터링
    initial begin
        $monitor("Time=%0t iFirIn=%b oFirOut=%h",
                 $time, iFirIn, oFirOut);
    end

    // 파형 덤프
    initial begin
        $dumpfile("fir_filter.vcd");
        $dumpvars(0, tb_fir_filter);
    end

endmodule