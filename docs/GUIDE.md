# 1.1.0 실행 순서

모든 실행 명령은 **Vivado Tcl Console**에 입력합니다.
`build/...`는 프로젝트 폴더 아래 경로입니다. 기본 검증과 Timing/Utilization 보고서 생성에는 Python이 필요 없습니다.

## 1. 파일 준비

[1.1.0 ZIP](https://github.com/CGM72/resnet20-core-rtl/raw/refs/heads/main/downloads/resnet20-core-rtl-v1.1.0.zip)을 새 폴더에 풉니다.
Git을 쓰면 Git Bash에서 다음 순서로 최신 main을 받습니다.

```bash
git fetch origin --tags
git switch main
git pull --ff-only origin main
```

`main`은 최신 1.1.0이며, 고정 버전은 `v1.0.0`·`v1.1.0` 태그로 보존합니다.
버전별 ZIP은 [README의 다운로드 표](../README.md)를 이용합니다.
ZIP 파일명에는 버전이 들어가며, 압축 안의 폴더는 기존 경로와 같은 `resnet20-core-rtl/`입니다.
RTL·TB 파일명과 `fpga::test`·`fpga::analyze` 명령은 동일합니다. 기본 구조입니다.

```text
project.tcl                  FPGA part / 클럭 / RTL / 모듈별 대상 설정
rtl/compute/
  core.v                     전체 연산 연결과 MAC/skip 정렬
  mac.v                      mac 및 bias 지원 mac_accumulate
  residual.v                 잔차 합과 포화
  relu.v                     ReLU / 우회
  pooling.v                  signed MaxPool
  general_average_pooling.v  2의 거듭제곱 N의 shift 평균
tb/tb_<모듈>/                독립 TB .sv 및 .f
tb/common/                   공통 driver/scoreboard와 사전 계산 정답
scripts/vivado.tcl            실행기
```

core의 포트·수치·입력 순서는 [구조 설명](architecture.md)을 따릅니다.
기본은 INT16/Q5.10 단일 lane입니다. 설정은 작업 중 고정하고 유효 출력은 모두 받아야 합니다.
GAP는 기본 N=1,2,4,…,1024만 지원합니다. 활성 상태의 0·비지원 크기는 입력을 폐기하므로 임의 N을 넣지 마십시오.
MAC 5단계·GAP 4단계에 맞춰 TB를 갱신했습니다. 전체 우회는 E0 입력 → E14 출력 → E15 소비입니다.
기본 targets는 위 6개 RTL을 사용합니다. 나머지 원본 AXI/controller 코드는 별도 통합 대상입니다.

## 2. 실행기 불러오기

열린 사용자 프로젝트를 저장하고 닫은 뒤 실제 경로로 source합니다.

```tcl
source {C:/Users/idec/Desktop/Chae/Project_ResNet/codes/resnet20-core-rtl/scripts/vivado.tcl}
```

source는 명령을 등록하며 아직 시뮬레이션이나 합성을 실행하지 않습니다.
Vivado를 다시 켰거나 실행기 파일을 교체했다면 source도 다시 합니다.

## 3. 모듈별 기능 검증

먼저 원하는 모듈 한 개를 검사합니다.

```tcl
fpga::test relu
```

| 모듈 | 독립 TB 파일 | 실행 명령 |
|---|---|---|
| core 연결 | tb/tb_core_stream/tb_core_stream.sv | fpga::test core |
| MAC와 bias MAC | tb/tb_mac/tb_mac.sv | fpga::test mac |
| Residual | tb/tb_residual/tb_residual.sv | fpga::test residual |
| ReLU | tb/tb_relu/tb_relu.sv | fpga::test relu |
| MaxPool | tb/tb_pooling/tb_pooling.sv | fpga::test pooling |
| GAP | tb/tb_general_average_pooling/tb_general_average_pooling.sv | fpga::test general_average_pooling |

각 하위 TB는 해당 DUT만 elaboration합니다. MAC TB는 같은 파일의 bias 경로도 함께 검사합니다.
공통 입력·기대값은 `tb/common/unit_vectors.txt`에 포함되어 있어 Python으로 생성할 필요가 없습니다.
비교는 매 클럭 valid와 signed 출력값을 함께 검사합니다. 우회·입력 공백·반올림·포화·음수·reset·여러 반복값을 포함합니다.
core TB는 추가로 skip 지연·연속 입력·Pool/GAP 조합과 정확한 출력 클럭을 검사합니다.

Console에서 **`[ PASS ] ALL TESTS PASSED`**를 확인합니다. `$fatal`/기대값 불일치는 실패입니다.
기능 시뮬레이션은 실제 FPGA 배선 지연을 검사하지 않습니다.

생성 위치는 `build/sim/<TB>/`입니다. 예를 들어 ReLU는:

```text
build/sim/tb_relu/
  sim_tb_relu.xpr
  sim_tb_relu.sim/sim_1/behav/xsim/
    *.log   compile/elaboration/simulation 로그
    *.wdb   파형
```

로그와 파형의 구체적인 파일명은 Vivado 버전에 따라 다를 수 있습니다.

## 4. 기능 PASS 후 Timing/Utilization 분석

기능 검증이 끝난 생성 프로젝트를 닫고 **같은 모듈**을 분석합니다.

```tcl
fpga::finish
fpga::analyze relu
```

analyze는 TB를 합성하지 않습니다. project.tcl의 해당 모듈 RTL과 top으로
**OOC 합성 → 합성 보고서 → 배치 → 배선 → 배선 후 보고서/DCP**를 생성합니다.
모듈별 실행 명령입니다.

```tcl
fpga::analyze core
fpga::analyze mac
fpga::analyze residual
fpga::analyze relu
fpga::analyze pooling
fpga::analyze general_average_pooling
```

위 명령은 선택 목록입니다. 한 작업이 끝난 뒤 **fpga::finish를 실행하고 다음 한 개**를 실행하십시오.
`fpga::finish`는 이 도구가 만든 프로젝트만 닫으며 수정된 파형 설정은 저장하지 않습니다.
다른 사용자 프로젝트는 수동으로 저장하고 닫습니다.

기본 목표는 project.tcl의 period_ns=10ns입니다. 이번 ReLU 분석만 20ns로 바꾸려면:

```tcl
fpga::analyze relu 20.0
```

mac.v 안에서 core가 실제 사용하는 bias MAC만 분석할 때는 `fpga::analyze mac_accumulate`를 사용합니다.
그 보고서 폴더의 top 이름은 mac_accumulate입니다.

### 저장 파일

ReLU 분석 예시입니다. core는 경로의 relu가 core로 바뀝니다.

```text
build/analysis/relu/
  latest.txt                            마지막 완료 실행 폴더의 전체 경로
  run_YYYYMMDD_HHMMSS/
    run_info.tcldict                     실행 조건과 캡처한 입력 목록
    clock.xdc                           분석 클럭 제약
    sources/                            분석 당시 RTL/설정 사본
    timing/
      post_synth.rpt                    합성 후 Timing Summary
      post_route.rpt                    배치배선 후 Timing Summary
      post_route_setup_paths.rpt        setup 최악 경로
      post_route_hold_paths.rpt         hold 최악 경로
      post_route_check_timing.rpt       제약 누락
      post_route_route_status.rpt       배선 상태
      post_route_drc.rpt                DRC
    utilization/
      post_synth.rpt                    합성 후 자원
      post_route.rpt                    배치배선 후 자원
      post_route_hierarchical.rpt       내부 계층별 자원
    checkpoints/
      relu_post_synth.dcp
      relu_post_route.dcp
```

실행할 때마다 새 폴더를 만들고 경로를 Console에 표시합니다. 같은 초에 실행하면 번호가 붙습니다.
정상 완료한 폴더는 latest.txt에서 찾습니다. 실패한 실행은 이전 완료 경로를 바꾸지 않습니다.
완료는 도구 실행이 끝났다는 뜻이며 타이밍을 만족했다는 뜻은 아닙니다.

| 확인 항목 | 파일과 기준 |
|---|---|
| Setup | timing/post_route.rpt: WNS>=0, TNS=0, 위반 endpoint 0 |
| Hold | WHS>=0, THS=0, 위반 endpoint 0 |
| Pulse | WPWS>=0, TPWS=0, pulse 위반 확인 |
| 제약/배선 | check_timing / route_status / DRC 보고서 |
| 자원 | utilization/post_route.rpt: LUT·FF·BRAM·DSP 사용량과 가용량 |

모듈 OOC 분석입니다. 외부 I/O·reset·추가 클럭 제약은 전체 시스템에서 완성해야 합니다.
1.1.0에서는 GAP의 가변 나눗셈을 제거하고 MAC의 곱셈·누산·반올림·포화를 분리했습니다.
누산 피드백 덧셈, GAP의 반올림/가변 shift, skip FIFO→Residual 경로 등 실제 최악 경로를 확인하십시오.
1.0.0과 비교할 때는 같은 part·클럭 주기·Vivado 버전에서 각각 analyze하여 post_route.rpt를 비교합니다.
레지스터 증가로 FF 사용량과 지연이 늘 수 있으며, 입력 처리율은 한 항/클럭으로 유지합니다.
100MHz는 목표이며 기능 PASS만으로 충족을 보장하지 않습니다.

## 5. PNG가 필요할 때만 변환

앞 단계의 .rpt가 생성된 다음 실행합니다. 현재 분석 프로젝트를 닫을 필요는 없습니다.
Python 3.10+와 Pillow가 필요합니다.

```tcl
fpga::python_command
exec {*}[fpga::python_command] -m pip install Pillow
fpga::images relu
```

해당 모듈의 latest.txt가 가리키는 완료 보고서에서 다음 PNG를 만듭니다.

```text
같은 실행 폴더/
  timing/post_synth.png
  timing/post_route.png
  utilization/post_synth.png
  utilization/post_route.png
```

발표용은 두 post_route.png를 사용하고, 세부 수치는 같은 폴더의 원본 .rpt로 확인합니다.
분석 후 RTL을 수정했더라도 캡처한 당시 입력으로 메타데이터를 만듭니다.
새 구현의 결과가 필요하면 analyze를 다시 실행합니다.

Python 자동 탐색이 실패하면 project.tcl의 python을 실제 경로로 설정하거나 다음과 같이 지정합니다.

```tcl
fpga::images relu {C:/실제설치폴더/python.exe}
```

Python 오류가 있어도 앞 단계의 Timing/Utilization .rpt는 그대로 사용할 수 있습니다.

## 6. 전체 모델·합성만·다른 RTL

- 전체 ResNet-20: `fpga::sim tb_core`. 입력과 22개 레이어 정답은 tb/tb_core/vectors/에 포함되어 있습니다. 단일 패턴 검증이며 CIFAR-10 전체 정확도 평가는 아닙니다.
- 합성만: `fpga::synth relu`. `build/synth/relu/`에 utilization.rpt, timing.rpt, relu.dcp, relu_funcsim.v를 생성합니다. 배치배선 결과는 없습니다.
- 같은 포트·수치·valid/지연 규약의 구현은 RTL만 교체하고 같은 TB를 실행합니다.
- 파일명/top/클럭이 바뀌면 project.tcl의 설정 또는 targets 항목을 수정합니다.
- 다른 기능/포트이면 전용 `tb/<TB>/<TB>.sv`와 TB 파일 목록 `<TB>.f`를 만들고 `fpga::sim <TB>`로 실행합니다. 기존 TB가 다른 기능을 자동 검증하지는 않습니다.
- 사용자 기본 설계는 project.tcl settings에 지정하고 `fpga::analyze`로 분석할 수 있습니다. 모듈 이름으로 실행하려면 targets에 top/rtl_files/tb를 등록합니다.

실행기에는 합성 top이나 DUT 포트가 고정되어 있지 않습니다. 기본 제공 core와 모듈들은 위 표의 targets로 연결되어 있습니다.
명령이 없으면 scripts/vivado.tcl을 다시 source하고, 프로젝트가 이미 열렸다면 생성 프로젝트는 fpga::finish로 닫습니다.

실제 Vivado 실행은 사용자 환경에서 수행합니다. 이 저장소의 로컬 검사는 Icarus/Verilator의 기능 검사와 Tcl 실행 구성 검사입니다.
