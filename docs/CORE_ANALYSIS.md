# Timing / Utilization을 PNG로 저장

기능 시뮬레이션과 별도로 **실제 rtl/compute/core.sv**를 합성·배치·배선합니다.
Vivado 원본 보고서를 읽어 Timing과 Utilization을 각각 PNG로 저장합니다.
실행 대상은 Zedboard의 `xc7z020clg484-1`, 기본 클럭 목표는 10ns입니다.

## 1. 이미지 도구 준비

Windows 명령 프롬프트에서 기존에 사용하는 Python에 한 번 설치합니다.

```bat
python -m pip install Pillow
```

Python 3.10+를 사용합니다. Matplotlib이나 별도 캡처 프로그램은 필요하지 않습니다.

## 2. Vivado에서 실행

기능 시뮬레이션이 열려 있으면 `close_sim -force`, `close_project`로 닫습니다.
다른 프로젝트가 열려 있으면 저장 후 닫습니다. 새 Vivado 창에서도 실행할 수 있습니다.

```tcl
source {C:/Users/idec/Desktop/Chae/Project_ResNet/codes/resnet20-core-rtl/scripts/analyze_core.tcl}
core_analysis::run core.sv 10.0
```

`core.sv`는 실제 RTL 파일명이고 10.0은 목표 주기 ns입니다.
20ns(목표 50MHz)로 다시 분석하려면 이전 프로젝트를 닫고 `core_analysis::run core.sv 20.0`을 실행합니다.
이 값은 목표이며 달성 주파수를 뜻하지 않습니다.
Python 경로를 지정하려면 다음과 같이 실행합니다.

```tcl
core_analysis::run core.sv 10.0 {C:/Python312/python.exe}
```

이 Python에 Pillow가 설치되어 있어야 합니다. 실행 전에 확인하며, 없으면 합성을 시작하지 않습니다.

## 3. 생성되는 파일

각 실행은 새 폴더를 만듭니다. Console에 전체 결과 경로가 출력됩니다.

```text
build/analysis/core/
  latest.txt                       마지막으로 성공한 실행의 경로
  run_YYYYMMDD_HHMMSS/
    run_info.json                  대상·클럭 목표·RTL hash
    core_clock.xdc                 합성 전 적용한 실행별 클럭 제약
    post_synth.json                 합성 후 수치
    post_route.json                 배치배선 후 수치
    timing/
      post_synth.png               합성 후 Timing 이미지
      post_route.png               배치배선 후 Timing 이미지
      post_synth.rpt               원본 Timing Summary
      post_route.rpt
      post_route_setup_paths.rpt   setup 최악 경로 10개
      post_route_hold_paths.rpt    hold 최악 경로 10개
      post_route_check_timing.rpt  제약 누락 확인
      post_route_drc.rpt           배치배선 후 DRC
      post_route_route_status.rpt  배선 완료/미배선 net 확인
    utilization/
      post_synth.png               합성 후 Utilization 이미지
      post_route.png               배치배선 후 Utilization 이미지
      post_synth.rpt               원본 자원 보고서
      post_route.rpt
      post_route_hierarchical.rpt  내부 모듈별 사용량
    checkpoints/
      core_post_synth.dcp
      core_post_route.dcp
```

setup/hold/check_timing/hierarchical 원본 보고서는 post_synth에도 저장합니다.
동일한 초에 재실행하면 폴더에 번호가 붙습니다. 실패한 실행은 기존 결과를 덮어쓰지 않고 latest.txt도 바꾸지 않습니다.
latest.txt는 도구 흐름 완료를 뜻하며 타이밍 충족 판정은 별도입니다. 음수 slack도 그대로 이미지로 저장합니다.

발표에는 보통 **timing/post_route.png**와 **utilization/post_route.png**를 사용합니다.
이미지는 1800×1150 PNG이며 단계·목표 클럭·원본 RTL hash를 표시합니다.
Vivado GUI에도 `timing_post_route`, `utilization_post_route` 보고서 탭을 생성합니다.

## 4. 이미지에서 볼 항목

| 이미지 | 확인 항목 |
|---|---|
| Timing | WNS/TNS: setup, WHS/THS: hold, 위반/분석 endpoint 수, WPWS/TPWS: pulse width |
| Utilization | LUT·FF·BRAM tile·DSP의 사용량 / 가용량과 사용률 |

Setup/Hold의 MET 표시는 **보고된 경로**에서 WNS/TNS/WHS/THS가 음수가 아니고 위반 endpoint가 없다는 뜻입니다.
N/A 또는 분석 endpoint가 없으면 INCOMPLETE이며 0이나 MET로 바꾸지 않습니다.
Pulse width 수치와 check_timing의 제약 누락도 함께 확인합니다.
자원 보고서의 필수 행을 읽을 수 없으면 0으로 추정하지 않고 오류를 반환합니다.

합성 후 Timing은 배선이 반영되지 않은 추정입니다. 최종 비교는 post_route를 사용합니다.
이 흐름은 core OOC 분석입니다. 외부 I/O delay와 reset 해제 제약은 아직 완성되지 않았으며,
Controller/BRAM/AXI를 포함한 전체 시스템의 타이밍·FPS·보드 동작을 판정하지 않습니다.

## 이미지 다시 만들기

원본 보고서가 남아 있으면 Vivado를 재실행하지 않고 PNG만 다시 만들 수 있습니다.
명령 프롬프트의 프로젝트 루트에서 실행합니다.

```bat
python scripts/export_analysis.py export --results "build/analysis/core/run_YYYYMMDD_HHMMSS" --stage post_route
```

실제 실행 폴더명을 넣습니다. 합성 후 이미지는 `--stage post_synth`로 생성합니다.
기존 `synthesis.bat`/`synthesis.sh`는 합성과 기능 넷리스트용으로 유지하며, PNG/배치배선 분석은 이 별도 Tcl을 사용합니다.

## 이 환경에서의 확인 범위

보고서 파싱/PNG 생성은 테스트용 수치로 검사했고, Tcl 실행 순서와 실패 처리는 Vivado API를 대체해 검사했습니다.
실제 Vivado 합성·배치배선은 여기서 수행하지 않았습니다. 실제 측정 PNG는 사용자 PC의 Vivado 실행 후 생성됩니다.
테스트 미리보기에는 TEST FIXTURE 표시를 넣으며 실측 결과로 제공하지 않습니다.
