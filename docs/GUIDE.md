# 실행 가이드

Tcl 명령은 Vivado Tcl Console에서 실행합니다. 기본 테스트와 보고서 생성에는 Python이 필요 없습니다.

## 소스 준비

[GitHub Releases](https://github.com/CGM72/resnet20-core-rtl/releases/tag/v1.2.7)에서 `resnet20-core-rtl-v1.2.7.zip`을 받아 새 폴더에 풉니다.

## 실행기 불러오기

Vivado에서 열려 있는 사용자 프로젝트를 저장하고 닫습니다. `C:/path/to`를 ZIP을 푼 위치로 바꿉니다. 다른 버전이라면 압축을 풀어 생성된 폴더 이름을 사용합니다.

```tcl
source {C:/path/to/resnet20-core-rtl-v1.2.7/scripts/vivado.tcl}
```

Vivado를 다시 시작하거나 실행기 파일을 교체했으면 `source`를 다시 실행합니다.

## 모듈 테스트와 분석 실행

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

다음 테스트·합성·분석을 시작하기 전에 생성 프로젝트를 `fpga::finish`로 닫습니다.
파형 설정을 저장하려면 닫기 전에 Vivado에서 저장합니다.
기본 part와 분석 주기는 `project.tcl`에서 설정합니다. 실행 한 번에만 20 ns를 지정하려면 `fpga::analyze relu 20.0`을 사용합니다.
합성까지만 실행하려면 `fpga::synth relu`를 사용합니다.

## 전체 모델과 파형

```tcl
fpga::sim tb_core
add_wave -r /tb_core/dut/*
```

모듈별 파형 경로와 결과 판정 기준은 [분석 가이드](ANALYSIS.md)를 따릅니다.

1.2.1 이상의 레이어별 SNR을 내보내려면 전체 모델 테스트 완료 후 저장소 루트에서 Python 3.10 이상으로 실행합니다.

```bash
python verification/core/golden_ref/check_snr.py
```

## 타이밍·Utilization 텍스트 저장

프로젝트를 닫은 상태에서 실행합니다.

```tcl
fpga::report
```

`fpga::analyze core`도 배치·배선 후 같은 `reports/core_report.txt`를 저장하므로 연달아 실행할 필요가 없습니다.
`fpga::analyze core`는 분석 프로젝트를 열어 두며, `fpga::report`는 작업 후 자동으로 닫습니다.
분석 클럭 제약을 지정하려면 `fpga::report 20.0`을 실행합니다. 이 흐름에는 Python이 필요 없습니다.
텍스트에는 Setup·Hold·Pulse Width의 slack, 위반 endpoint와 상태, 그리고 LUT·FF·BRAM·DSP의 사용량과 사용률을 저장합니다.
Vivado 원본은 해당 `build/analysis/core/run_*/` 아래에 있습니다.

## SNR·latency 별도 저장

전체 모델 결과가 필요한 경우에 실행합니다. Python 3.10 이상이 필요합니다.

```tcl
fpga::report_sim
```

결과는 `reports/snr_latency.txt`에 저장됩니다. 같은 조건의 완료된 시뮬레이션은 재사용합니다.
PATH에서 Verilator를 찾으면 사용하고, 없으면 XSim으로 실행합니다. Verilator 빌드 도구 없이 실행하려면 `fpga::report_sim {} xsim`으로 XSim을 지정합니다.
Python을 직접 지정하려면 `fpga::report_sim {C:/path/to/python.exe}`를 실행합니다.

## 버전별 보고서 비교

비교할 버전에서 각각 `fpga::report`를 실행합니다. 1.2.5부터는 `reports/generated/v<버전>/core_report.txt`에도 결과를 저장합니다.
이 폴더를 한 저장소의 `reports/generated/` 아래에 모은 뒤 최신 실행기를 불러와 실행합니다.

```tcl
fpga::compare
```

별도 폴더에 풀어둔 버전은 각 보고서의 경로를 직접 넘겨도 됩니다.

```tcl
fpga::compare {C:/projects/resnet20-core-rtl-v1.2.4/reports/core_report.txt} {C:/projects/resnet20-core-rtl-v1.2.7/reports/core_report.txt}
```

1.2.1~1.2.3의 기존 자료는 `build/analysis/core/run_...` 폴더를 지정합니다. 측정 파일이 없는 항목은 `N/A`로 표시됩니다.
SNR·latency끼리 비교하려면 두 버전의 `reports/snr_latency.txt` 경로를 직접 넘깁니다. 비교 결과는 `reports/version_comparison.txt`에 저장됩니다.

## PNG 변환

분석을 완료한 모듈의 보고서를 PNG로 변환할 때 Python 3.10 이상과 Pillow를 사용합니다.

```tcl
exec {*}[fpga::python_command] -E -m pip install Pillow
fpga::images relu
```

자동 탐색이 실패하면 `project.tcl`의 `python` 설정을 바꾸거나 `fpga::images relu {C:/path/to/python.exe}`로 실행합니다.

## 사용자 RTL과 테스트벤치 실행

1. `project.tcl`의 `settings`에 RTL 경로와 top을 설정합니다.
2. `tb/<TB>/<TB>.sv`와 `tb/<TB>/<TB>.f`를 준비합니다.
3. `fpga::sim <TB>`로 실행합니다. 모듈 이름으로 실행하려면 `targets`에 top, rtl_files, tb를 등록하고 `fpga::test <target>`을 사용합니다.
4. 생성 프로젝트를 닫고 `fpga::analyze` 또는 `fpga::analyze <target>`을 실행합니다.
