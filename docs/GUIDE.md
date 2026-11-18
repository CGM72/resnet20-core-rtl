# 사용 가이드

기능 검증과 FPGA 구현 분석을 구분합니다.

| 목적 | Vivado Tcl 명령 | 결과 |
|---|---|---|
| 기능 검증 | `fpga::sim tb_core_stream` | 파형과 TB의 기대값 비교 |
| Timing/자원 분석 | `fpga::analyze` | 합성·배치배선 보고서와 PNG |
| 합성만 실행 | `fpga::synth` | 합성 보고서·DCP·기능 넷리스트 |

## 1. 준비와 실행

Vivado와 Python 3.10+를 사용합니다. PNG 출력에는 Pillow가 필요합니다.
Windows 명령 프롬프트에서 한 번 설치합니다.

```bat
python -m pip install Pillow
```

Vivado에서 열린 프로젝트를 저장하고 닫은 뒤 Tcl Console에서 실행기를 불러옵니다.

```tcl
source {C:/Users/idec/Desktop/Chae/Project_ResNet/codes/resnet20-core-rtl/scripts/vivado.tcl}
fpga::sim tb_core_stream
```

이후 명령은 프로젝트를 다시 열지 않은 상태에서 실행합니다.
시뮬레이션이 열려 있으면 `close_sim -force`, `close_project`를 사용합니다.
분석만 열려 있으면 `close_project`로 닫습니다. `-force`는 변경된 파형 설정을 저장하지 않고 닫습니다.

기본 제공 TB는 다음과 같습니다.

| TB | 검사 |
|---|---|
| tb_modules | MAC·bias·Residual·ReLU·MaxPool·GAP의 수치와 valid 타이밍 |
| tb_core_stream | core 연결, skip 지연, Pool/GAP 조합, reset 복구 |
| tb_core | ResNet-20 전체 연산, 22개 레이어 정수 정답과 로짓 SNR |

`fpga::sim tb_modules.sv`처럼 파일명을 넣어도 됩니다.
기본 TB는 `[ PASS ] ALL TESTS PASSED`를 확인합니다. 파형이 나온 것만으로 기능 검증이 끝난 것은 아닙니다.
전체 모델은 단일 MAC의 수천만 입력 클럭을 실행하므로 오래 걸릴 수 있습니다.

## 2. 다른 사람이 작성한 RTL 적용

### 같은 인터페이스의 구현으로 교체

기존 RTL과 포트·기능·수치·valid/지연 규약이 같으면 해당 파일을 교체하고 같은 TB를 실행합니다.
파일 이름까지 같다면 설정을 바꾸지 않아도 됩니다.

파일명·하위 파일이 달라지면 **project.tcl의 rtl_files만** 수정합니다.
기존 RTL과 새 RTL에 같은 module 이름이 있으면 둘을 동시에 목록에 넣지 않습니다.

### 다른 top/포트/기능의 모듈 적용

예를 들어 파일은 `rtl/custom/filter_impl.sv`, 내부 선언은 `module my_filter`, 클럭은 `aclk`라면
project.tcl의 settings를 다음과 같이 바꿉니다. top은 파일명이 아닌 **module 선언 이름**입니다.

```tcl
namespace eval ::fpga_project {
    variable settings [dict create \
        part xc7z020clg484-1 \
        top my_filter \
        clock_port aclk \
        period_ns 10.0 \
        python python \
        rtl_files {rtl/custom/filter_impl.sv} \
        include_dirs {} \
        defines {} \
        xdc_files {}]
}
```

같은 파일에 남아 있는 기본 `fixtures` 항목은 새 TB에 적용되지 않습니다. 필요 없으면 삭제해도 됩니다.
Tcl 목록에는 쉼표를 넣지 않습니다. 경로에 공백이 있으면 `{rtl/my files/filter_impl.sv}`처럼 묶습니다.

그 모듈의 포트로 연결하고 기대값을 비교하는 TB를 만듭니다.

```text
tb/tb_my_filter/
  tb_my_filter.sv       module tb_my_filter 선언
  tb_my_filter.f        TB와 검증 전용 파일 목록
```

`tb_my_filter.f`에는 다음처럼 적습니다. 경로는 이 .f가 있는 폴더 기준이며 한 줄에 파일 하나입니다.
RTL 목록은 project.tcl에만 관리합니다.

```text
tb_my_filter.sv
```

Vivado에서 실행합니다. 실행기에는 새 TB 이름을 등록할 필요가 없습니다.

```tcl
fpga::sim tb_my_filter
```

새 TB는 자신의 clock/reset과 입력을 만들고 출력을 기대값과 비교해야 합니다.
기존 ResNet TB가 다른 기능의 모듈을 자동으로 검증해 주지는 않습니다.
단순히 기존 모듈을 감싸 포트를 맞출 수 있으면 adapter/wrapper RTL을 사용해도 됩니다.

### 추가 설정

| project.tcl 항목 | 변경할 경우 |
|---|---|
| rtl_files | 합성할 .v/.sv 파일 목록. package 등 의존 파일을 먼저 배치 |
| top | 합성할 최상위 module 이름 |
| clock_port / period_ns | 기본 클럭 포트 / 목표 주기 ns |
| part | 다른 FPGA device 사용 |
| include_dirs | RTL이 `include`하는 .vh/.svh 폴더 |
| defines | `{USE_FEATURE WIDTH=16}` 같은 전처리 define |
| xdc_files | 추가 클럭·입출력 지연 등 XDC. 자동 생성하는 주 클럭과 중복 정의하지 않음 |
| python | `python` 또는 `{C:/Python312/python.exe}` |

클럭 없는 조합 모듈은 `clock_port {}`로 두면 자동 clock 제약을 생략합니다.
이 경우 Timing 분석에는 virtual clock·입출력 지연 등 별도 XDC가 필요하며 경로가 없으면 INCOMPLETE입니다.

모든 상대 경로는 프로젝트 루트 기준입니다. TB 전용 include 폴더는 `tb/<이름>/include/`에 놓으면 자동 적용됩니다.
새 TB가 파일 입력 없이 실행되면 Python을 호출하지 않습니다.
기본 core의 데이터 생성은 project.tcl의 fixtures 항목으로 연결되어 있습니다.

## 3. Timing·Utilization 이미지

프로젝트를 닫고 실행합니다.

```tcl
fpga::analyze
```

project.tcl의 top·RTL·part·클럭 설정으로 합성→배치→배선을 실행합니다.
이번 실행만 20ns로 바꾸려면 `fpga::analyze 20.0`을 사용합니다.
period_ns는 합성·분석 목표입니다. 시뮬레이션 clock은 TB에서 별도로 생성합니다.

```text
build/analysis/<top>/<실행폴더>/
  timing/post_route.png              Timing 요약
  utilization/post_route.png         자원 사용량
  timing/*.rpt                      원본 Timing/최악 경로/제약/DRC 보고서
  utilization/*_hierarchical.rpt     내부 모듈별 자원
  checkpoints/                      합성 후·배치배선 후 DCP
```

합성 후 이미지는 각 폴더의 `post_synth.png`입니다.
`build/analysis/<top>/latest.txt`에는 마지막으로 흐름이 완료된 폴더가 기록됩니다.
타이밍 위반도 수치를 그대로 저장하며, 흐름 완료와 타이밍 충족은 별개입니다.

| 항목 | 확인 |
|---|---|
| Timing | WNS/TNS: setup, WHS/THS: hold, pulse width, 위반 endpoint |
| 제약 | check_timing 및 route_status 보고서의 제약 누락/미배선 |
| Utilization | LUT·FF·BRAM tile·DSP의 사용량과 가용량 |

PNG의 MET는 보고된 setup/hold 경로 기준입니다. 분석값이 없으면 INCOMPLETE이며 0으로 추정하지 않습니다.
OOC 분석은 모듈 단독 결과입니다. 전체 시스템은 외부 I/O·reset·추가 클럭 제약까지 확인해야 합니다.
100MHz 목표가 실제 달성 주파수나 보드 FPS를 보장하지 않습니다.

## 4. 자주 막히는 부분

- 파일을 바꾼 뒤: project.tcl은 명령 실행마다 다시 읽습니다. 실행기를 수정했다면 source도 다시 합니다.
- 프로젝트가 이미 열림: 저장 후 닫습니다. 실행기가 사용자 프로젝트를 자동으로 덮어쓰지 않습니다.
- 파일 없음: project.tcl은 프로젝트 루트 기준, TB .f는 TB 폴더 기준입니다.
- compile에서 포트 오류: 교체한 RTL과 TB의 포트·폭·parameter를 맞춥니다.
- 숫자만 다름: signed, 소수부, 반올림/포화와 출력 valid/지연 규약을 확인합니다.
- Python/Pillow 오류: project.tcl에 지정한 같은 Python으로 `-m pip install Pillow`를 실행합니다.
- 합성 결과만 필요: Pillow 없이 `fpga::synth`를 사용합니다. 결과는 `build/synth/<top>/`입니다.

실행기는 순수 Verilog/SystemVerilog RTL을 대상으로 합니다. IP/Block Design에는 해당 생성·제약 작업도 필요합니다.
도구 회귀검사는 `verification/tools/`에 있으며, 실제 Vivado 결과는 사용자 환경에서 생성합니다.
