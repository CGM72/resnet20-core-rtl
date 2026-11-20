# 실행 가이드

## 목차

1. [준비와 실행기 불러오기](#1-준비와-실행기-불러오기)
2. [원하는 작업 선택](#2-원하는-작업-선택)
3. [타이밍·Utilization 보고서](#3-타이밍utilization-보고서)
4. [기능 테스트와 파형](#4-기능-테스트와-파형)
5. [SNR·latency 별도 저장](#5-snrlatency-별도-저장)
6. [선택 작업](#6-선택-작업)
    - [6.1 보고서를 PNG로 변환](#61-보고서를-png로-변환)
    - [6.2 사용자 RTL과 테스트벤치 실행](#62-사용자-rtl과-테스트벤치-실행)

아래 Tcl 명령은 **Vivado Tcl Console**에서 실행합니다. 기본 기능 테스트와 타이밍·Utilization 보고서에는 Python이 필요 없습니다.

## 1. 준비와 실행기 불러오기

1. 1.3.0 ZIP을 내려받아 새 폴더에 풉니다. [1.3.0 다운로드](https://github.com/CGM72/resnet20-core-rtl/releases/tag/v1.3.0)
2. Vivado에 열려 있는 사용자 프로젝트를 저장하고 닫습니다.
3. `C:/path/to`를 실제 압축 해제 위치로 바꿔 실행기를 불러옵니다.

```tcl
source {C:/path/to/resnet20-core-rtl-v1.3.0/scripts/vivado.tcl}
```

Vivado를 다시 시작했거나 다른 버전의 실행기를 쓰려면 해당 경로로 `source`를 다시 실행합니다.

## 2. 원하는 작업 선택

아래 명령 중 필요한 작업 하나를 실행합니다. 새 작업을 시작하기 전, 이전 명령으로 열린 프로젝트는 `fpga::finish`로 닫습니다. 저장할 파형 설정이 있으면 먼저 저장합니다.

| 필요할 때 | Tcl 명령 | 결과 |
| --- | --- | --- |
| core의 타이밍과 Utilization 확인 | `fpga::report` 또는 `fpga::analyze core` | `reports/core_report.html` |
| core 연결 기능 테스트 | `fpga::test core` | 콘솔 PASS와 시뮬레이션 파형 |
| 전체 모델의 SNR과 latency 확인 | `fpga::report_sim` | `reports/snr_latency.txt` |
| 전체 모델 시뮬레이션 파형 확인 | `fpga::sim tb_core` | Vivado 파형 창 |

## 3. 타이밍·Utilization 보고서

프로젝트를 닫은 상태에서 실행합니다.

```tcl
fpga::report
```

- **빠르게 확인**하려면 브라우저에서 `reports/core_report.html`을 엽니다. Setup·Hold·Pulse Width와 자원 사용량을 볼 수 있습니다.
- **원본 확인**은 `build/analysis/core/latest.txt`가 가리키는 실행 폴더에서 시작합니다. `timing/post_route.rpt`와 `utilization/post_route.rpt`가 Vivado 원본입니다.
- **다른 클럭 제약**으로 분석하려면 `fpga::report 20.0`을 실행합니다. 값의 단위는 ns입니다.

`fpga::report`와 `fpga::analyze core`는 같은 HTML을 저장하므로 연달아 실행할 필요가 없습니다. 두 명령 모두 저장 후 분석 프로젝트를 열어 둡니다. 판정 기준은 [분석 가이드](ANALYSIS.md#3-타이밍과-utilization)를 참고합니다.

## 4. 기능 테스트와 파형

아래는 ReLU를 검사한 뒤 배치·배선까지 진행하는 예입니다.

```tcl
fpga::test relu
# 콘솔에서 [ PASS ] ALL TESTS PASSED 확인
fpga::finish
fpga::analyze relu
```

| 대상 | 기능 테스트 | 합성·배치·배선 |
| --- | --- | --- |
| core | `fpga::test core` | `fpga::analyze core` |
| MAC | `fpga::test mac` | `fpga::analyze mac` |
| bias MAC | `fpga::test mac_accumulate` | `fpga::analyze mac_accumulate` |
| Residual | `fpga::test residual` | `fpga::analyze residual` |
| ReLU | `fpga::test relu` | `fpga::analyze relu` |
| MaxPool | `fpga::test pooling` | `fpga::analyze pooling` |
| GAP | `fpga::test general_average_pooling` | `fpga::analyze general_average_pooling` |

합성까지만 하려면 `fpga::synth <대상>`을 사용합니다. 기본 FPGA part와 분석 주기는 `project.tcl`에 있습니다.

전체 모델의 DUT 내부 신호를 보려면 다음처럼 실행합니다. 신호 경로와 지연 해석은 [파형 공통 기준](ANALYSIS.md#5-파형-공통-기준)을 참고합니다.

```tcl
fpga::sim tb_core
add_wave -r /tb_core/dut/*
```

## 5. SNR·latency 별도 저장

Python 3.10 이상이 설치된 환경에서 실행합니다.

```tcl
fpga::report_sim
```

결과는 `reports/snr_latency.txt`에 저장됩니다. 같은 입력·가중치·도구·RTL로 완료된 시뮬레이션이 있으면 재사용합니다. PATH에서 Verilator를 찾으면 사용하고, 없으면 XSim으로 실행합니다.

| 상황 | Tcl 명령 |
| --- | --- |
| XSim으로 실행 | `fpga::report_sim {} xsim` |
| Python 경로를 직접 지정 | `fpga::report_sim {C:/path/to/python.exe}` |

`fpga::sim tb_core`에서 이미 저장한 RTL 출력으로 SNR만 다시 계산하려면 저장소 루트의 터미널에서 실행합니다.

```sh
python verification/core/golden_ref/check_snr.py
```

## 6. 선택 작업

### 6.1 보고서를 PNG로 변환

완료된 Vivado 분석 결과를 이미지로 내보낼 때 사용합니다. Python 3.10 이상과 Pillow가 필요합니다.

```tcl
exec {*}[fpga::python_command] -E -m pip install Pillow
fpga::images relu
```

Python 자동 탐색이 실패하면 `fpga::images relu {C:/path/to/python.exe}`로 지정합니다.

### 6.2 사용자 RTL과 테스트벤치 실행

1. `project.tcl`의 `settings`에 RTL 경로와 top을 설정합니다.
2. `tb/<TB>/<TB>.sv`와 소스 목록 `tb/<TB>/<TB>.f`를 준비합니다.
3. `fpga::sim <TB>`로 실행합니다. 모듈 이름으로 실행하려면 `targets`에 top, rtl_files, tb를 등록하고 `fpga::test <target>`을 사용합니다.
4. 생성 프로젝트를 닫고 `fpga::analyze` 또는 `fpga::analyze <target>`을 실행합니다.
