# 사용 SoC와 통합 전제

## 목차

1. [대상 보드와 Vivado 설정](#1-대상-보드와-vivado-설정)
2. [PS와 PL의 통합 범위](#2-ps와-pl의-통합-범위)
3. [버전별 전제](#3-버전별-전제)
4. [제약과 실제 보드 연결](#4-제약과-실제-보드-연결)
5. [다른 SoC에 사용할 때](#5-다른-soc에-사용할-때)

**SoC(System on Chip)**는 CPU와 주변장치 등을 한 칩에 통합한 구성입니다.
이 프로젝트의 Zynq-7000은 ARM CPU 영역인 **PS(Processing System)**와 FPGA 회로 영역인 **PL(Programmable Logic)**을 한 칩에 포함합니다.
ZedBoard는 이 SoC를 탑재한 개발 보드이며, core RTL은 PL에 구현하는 연산 회로입니다.

## 1. 대상 보드와 Vivado 설정

| 항목 | 모든 제공 버전의 기본 전제 |
|---|---|
| 보드 | ZedBoard |
| SoC | AMD/Xilinx Zynq-7000 XC7Z020 |
| Vivado part | `xc7z020clg484-1` |
| PS | Dual-core ARM Cortex-A9. 소프트웨어 제어·데이터 준비를 맡도록 통합 가능 |
| PL | MAC·Residual·ReLU·MaxPool·GAP 및 core 구현 위치 |
| PL 가용 자원 | LUT 53,200 / FF 106,400 / DSP48E1 220개 |
| 분석 목표 클럭 | clk 포트 10ns, 100MHz |
| 기본 수치 | signed INT16, Q5.10, 단일 lane MAC |
| reset / 데이터 수신 | nrst 비동기 active-low, in_enable=1인 상승 에지 수신 |

## 2. PS와 PL의 통합 범위

현재 제공 범위는 core와 연산 모듈, 기능 TB, 모듈 OOC 분석입니다.
PS 설정·AXI/DMA·메모리/주소 제어·레이어 실행 순서는 시스템 통합자가 구성합니다.
저장소의 원본 Controller/AXI 관련 파일은 기본 core 분석 파일 목록과 구분됩니다.
PS를 사용하지 않고 PL 테스트 회로/외부 컨트롤러로 core를 구동해도 연산 규약은 같습니다.

```text
ZedBoard / Zynq XC7Z020
  PS: ARM Cortex-A9 / 소프트웨어·메모리 관리
      ↕ 시스템에서 구성할 AXI·DMA 연결
  PL: Controller·BRAM ↔ core
                       MAC → Residual → ReLU → MaxPool → GAP
```

## 3. 버전별 전제

| 버전 | SoC / part | MAC / GAP 단계 | 전체 우회 | GAP N |
|---|---|---|---|---|
| 1.0.0 | XC7Z020 / xc7z020clg484-1 | 2 / 2 | E0 입력 → E9 출력 | 기본 16비트 포트의 양수 1..65535 |
| 1.1.0 | 동일 | 5 / 4 | E0 입력 → E14 출력 | 기본 1,2,4,…,1024 |
| 1.1.1 | 동일 | 5 / 4 | E0 입력 → E14 출력 | 1.1.0과 동일 |

E0은 입력 수신 상승 에지이며 출력 시점은 해당 에지의 레지스터 갱신 직후입니다.
1.1.1은 1.1.0의 가독성 패치이며 포트·신호명·비트폭·논리식·레지스터·합성 속성을 유지합니다.
1.0.0/1.1.0 실측 이미지와 1.1.1의 동등성 검증은 [리포트](../reports/README.md)에서 구분합니다.

## 4. 제약과 실제 보드 연결

- 대상 part/clk/주기는 `project.tcl`에 지정합니다. 실행기는 분석 폴더에 `clock.xdc`를 생성합니다.
- 기본 제약은 `create_clock -name design_clk -period 10.0 [get_ports clk]`입니다.
- 보드 Master XDC와 저장소의 core_ooc.xdc는 기본 실행 경로에서 추가로 읽지 않습니다.
- 실제 클럭 공급원(PS FCLK 또는 보드 클럭), 핀, 외부 I/O 지연과 reset 해제 조건은 최상위 시스템에서 구성합니다.
- OOC는 모듈 내부 회로 분석입니다. 전체 PS/PL 연결과 외부 포트의 타이밍을 자동 검증하지 않습니다.
- ready 포트가 없으므로 모든 유효 출력을 수신하고, 설정은 첫 입력 전부터 모든 결과 배출까지 유지합니다.

## 5. 다른 SoC에 사용할 때

같은 Verilog가 합성 가능한 디바이스로 이식할 수 있지만, part·클럭·메모리·핀 제약과 자원 여유를 다시 지정하고 검증해야 합니다.
기본 TB가 Zynq의 ARM 코드를 실행하는 것은 아니며 RTL 연산과 데이터/valid 정렬을 검사합니다.
