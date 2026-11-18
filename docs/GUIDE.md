# 실행 명령과 결과 확인

아래 명령은 별도 표시가 없으면 **Vivado의 Tcl Console**에 입력합니다.
모든 `build/...` 경로는 압축을 푼 프로젝트 폴더 기준입니다.

## 1. 처음 실행

ZIP은 새 폴더에 풉니다. 열린 Vivado 프로젝트는 저장하고 닫습니다.
자신의 실제 경로로 실행기를 불러옵니다.

```tcl
source {C:/Users/idec/Desktop/Chae/Project_ResNet/codes/resnet20-core-rtl/scripts/vivado.tcl}
```

이 명령은 `fpga::...` 명령을 등록합니다. 합성이나 시뮬레이션을 시작하지 않습니다.
새 Vivado 창을 열었거나 vivado.tcl을 교체했다면 source를 다시 실행합니다.

### Python과 이미지 준비

```tcl
fpga::python_command
```

project.tcl의 Python 설정을 확인하고 실행 가능한 Python 3.10+ 명령을 표시합니다.
기본 `auto`는 `python`, `python3`, `py -3`, Windows 일반 설치 폴더를 탐색합니다.
Python 자체가 없다면 Python 3.10 이상을 먼저 설치합니다.

PNG 출력에 필요한 Pillow를 같은 Python에 설치합니다. 이미 설치돼 있으면 다시 설치하지 않습니다.

```tcl
exec {*}[fpga::python_command] -m pip install Pillow
```

설치된 Python의 실제 위치를 확인하려면 다음을 입력합니다.

```tcl
exec {*}[fpga::python_command] -c {import sys; print(sys.executable)}
```

자동 탐색이 안 되면 실제 경로를 직접 지정할 수 있습니다.

```tcl
fpga::analyze 10.0 {C:/실제설치폴더/python.exe}
```

항상 같은 Python을 쓰려면 project.tcl의 `python auto`를 `python {C:/실제설치폴더/python.exe}`로 바꿉니다.
이후 Pillow 설치와 분석 모두 그 Python을 사용합니다.
이번 실행만 경로를 지정했다면 Pillow 설치도 `exec {*}[fpga::python_command {C:/실제설치폴더/python.exe}] -m pip install Pillow`처럼 같은 경로를 넣습니다.
명령 프롬프트에서 설치 경로를 찾을 때는 `py -0p` 또는 `where python`을 사용합니다.

## 2. 무슨 명령을 실행할지 선택

`<top>`은 project.tcl의 top 값입니다. 기본 예제에서는 `core`입니다.

| Tcl 명령 | 하는 일 | 결과 저장 위치 |
|---|---|---|
| `fpga::sim tb_modules` | 하위 모듈의 연산·반올림·포화·valid 검사 | `build/sim/tb_modules/` |
| `fpga::sim tb_core_stream` | core 연결·skip 지연·Pool/GAP 조합·reset 검사 | `build/sim/tb_core_stream/` |
| `fpga::sim tb_core` | 전체 ResNet-20, 22개 레이어 정수 정답과 로짓 SNR 검사 | `build/sim/tb_core/` |
| `fpga::synth` | 설정된 주기로 OOC 합성. 배치배선/PNG 생성은 하지 않음 | `build/synth/<top>/` |
| `fpga::synth 20.0` | 이번 실행만 20ns 목표로 합성 | 같은 합성 폴더, 기존 파일 갱신 |
| `fpga::analyze` | 설정된 주기로 합성→배치배선→보고서·PNG 생성 | `build/analysis/<top>/<실행폴더>/` |
| `fpga::analyze 20.0` | 이번 실행만 20ns 목표로 같은 전체 분석 | 새 분석 실행 폴더 |

- `fpga::sim tb_modules.sv`처럼 TB 파일명을 넣어도 됩니다.
- 기본 주기는 project.tcl의 `period_ns`입니다. 10ns는 목표 100MHz, 20ns는 목표 50MHz입니다.
- 목표 주기는 달성 주파수를 보장하지 않습니다. 시뮬레이션 clock은 TB에서 별도로 생성합니다.
- `tb_core_stream`과 합성만 실행하는 `fpga::synth`에는 Python/Pillow가 필요하지 않습니다.
- 기본 수치 TB의 데이터 생성에는 Python, 분석 PNG에는 Python과 Pillow가 필요합니다.
- 전체 ResNet-20 시뮬레이션은 수천만 입력 클럭을 실행하므로 오래 걸릴 수 있습니다.

### 다른 작업으로 넘어갈 때

시뮬레이션을 실행한 뒤에는 다음 두 명령으로 닫습니다.

```tcl
close_sim -force
close_project
```

합성이나 분석만 실행했다면 `close_project`만 사용합니다.
`-force`는 변경된 파형 설정을 저장하지 않고 닫습니다. 보존할 파형 설정은 먼저 저장합니다.

예를 들어 기능 검사 후 Timing/자원 분석으로 넘어가는 순서입니다.

```tcl
fpga::sim tb_core_stream
# PASS 확인 후
close_sim -force
close_project
set result_dir [fpga::analyze]
puts [file nativename $result_dir]
```

마지막 줄은 분석이 정상 종료된 뒤 결과 폴더의 전체 경로를 표시합니다.
출력된 경로를 Windows 탐색기의 주소창에 붙여넣으면 됩니다.

## 3. 결과 파일은 어디에 있는가

### 기능 시뮬레이션

기본 core 연결 검사 예시입니다.

```text
build/sim/tb_core_stream/
  sim_tb_core_stream.xpr
  sim_tb_core_stream.sim/sim_1/behav/xsim/
    *.log       compile / elaboration / simulation 로그
    *.wdb       파형 데이터
```

다른 TB는 폴더와 프로젝트 이름의 `tb_core_stream` 부분이 해당 TB 이름으로 바뀝니다.
`.log`와 `.wdb`의 구체적인 이름은 Vivado 버전과 설정에 따라 달라질 수 있습니다.

| 생성 데이터 | 위치 |
|---|---|
| 모듈 검사 입력·정답 | `build/sim/tb_modules/unit_vectors.txt` |
| 전체 모델 입력·레이어별 정답 | `build/sim/tb_core/vectors/` |

기본 TB는 Console/시뮬레이션 로그에서 **`[ PASS ] ALL TESTS PASSED`**를 확인합니다.
`Fatal`이나 기대값 불일치가 있으면 실패입니다. 파형이 나온 것만으로 기능 PASS는 아닙니다.
다른 사람이 만든 TB는 그 TB의 assertion/기대값 판정도 확인해야 합니다.

### 합성만 실행한 결과

`fpga::synth`가 생성하는 기본 core 파일입니다.

```text
build/synth/core/
  utilization.rpt     합성 자원 사용량
  timing.rpt          합성 후 Timing 추정
  core.dcp            합성 설계 checkpoint
  core_funcsim.v      기능 시뮬레이션용 넷리스트
  clock.xdc           자동 생성 클럭 제약, clock_port 설정 시
```

이 폴더에는 PNG나 배치배선 결과가 없습니다.
top을 바꾸면 폴더명과 DCP/넷리스트의 `core` 부분도 그 이름으로 바뀝니다.
넷리스트 파일이 생성됐다는 것만으로 post-synthesis 기능 시뮬레이션이 실행된 것은 아닙니다.

### Timing·Utilization 전체 분석

`fpga::analyze`는 합성 후 보고서/PNG를 만든 뒤 배치·배선을 실행하고 배선 후 보고서/PNG를 만듭니다.
기본 core 결과는 다음과 같습니다.

```text
build/analysis/core/
  latest.txt                           마지막 완료 폴더의 전체 경로
  run_YYYYMMDD_HHMMSS/
    run_info.json                      top·part·주기·입력 파일 정보
    clock.xdc                          자동 생성 주 클럭 제약
    post_synth.json                    합성 후 수치
    post_route.json                    배치배선 후 수치
    timing/
      post_synth.png                   합성 후 Timing 이미지
      post_route.png                   배치배선 후 Timing 이미지
      post_synth.rpt                   합성 후 원본 Timing Summary
      post_route.rpt                   배치배선 후 원본 Timing Summary
      post_route_setup_paths.rpt       setup 최악 경로
      post_route_hold_paths.rpt        hold 최악 경로
      post_route_check_timing.rpt      제약 누락
      post_route_route_status.rpt      배선 상태
      post_route_drc.rpt               DRC
    utilization/
      post_synth.png                   합성 후 자원 이미지
      post_route.png                   배치배선 후 자원 이미지
      post_synth.rpt                   합성 후 원본 자원 보고서
      post_route.rpt                   배치배선 후 원본 자원 보고서
      post_route_hierarchical.rpt      내부 모듈별 자원
    checkpoints/
      core_post_synth.dcp
      core_post_route.dcp
```

setup/hold/check_timing/hierarchical 보고서는 post_synth 단계에도 생성합니다.
같은 시각에 실행 폴더가 이미 있으면 `_1`, `_2` 등의 번호를 붙입니다.
top을 바꾸면 `build/analysis/<top>/`과 checkpoint 이름도 바뀝니다.

**발표용 사진은 `timing/post_route.png`, `utilization/post_route.png`를 사용합니다.**
원본 수치를 자세히 볼 때는 같은 폴더의 `.rpt`를 엽니다.
`latest.txt`는 도구 흐름 완료를 뜻합니다. Timing이 VIOLATED여도 분석/이미지 생성이 완료되면 기록됩니다.
분석 오류로 중단되면 Console의 부분 결과 경로를 확인합니다. 이전 완료 경로는 유지됩니다.

| 확인할 것 | 보는 파일 / 기준 |
|---|---|
| Setup | Timing PNG 또는 post_route.rpt의 WNS>=0, TNS=0, 위반 endpoint 0 |
| Hold | WHS>=0, THS=0, 위반 endpoint 0 |
| Pulse width | WPWS>=0, TPWS=0, pulse 위반 endpoint 0 확인 |
| 제약/배선 | check_timing 및 route_status 보고서 |
| 자원 | Utilization PNG 또는 post_route.rpt의 LUT·FF·BRAM tile·DSP |
| 어느 모듈이 자원을 쓰는지 | post_route_hierarchical.rpt |

PNG의 MET는 **보고된 setup/hold 경로** 기준입니다. 값/경로가 없으면 INCOMPLETE이며 0으로 추정하지 않습니다.
OOC는 모듈 단독 분석입니다. 전체 시스템은 외부 I/O·reset·추가 클럭 제약까지 확인해야 합니다.
기능 PASS, 흐름 완료, 실제 FPGA 타이밍 충족은 각각 별도 판정입니다.

## 4. 다른 사람이 작성한 RTL 적용

같은 포트·기능·수치·valid/지연 규약이면 해당 RTL 파일을 교체하고 같은 TB를 실행합니다.
파일 이름까지 같으면 설정을 바꾸지 않아도 됩니다.
파일명/하위 파일이 달라지면 project.tcl의 **rtl_files**를 바꾸며 같은 module 이름의 구현을 중복 등록하지 않습니다.

다른 top/포트/기능이라면 그 모듈에 맞는 TB가 필요합니다.
예를 들어 파일은 `rtl/custom/filter_impl.sv`, 선언은 `module my_filter`, 클럭은 `aclk`인 경우입니다.

```tcl
namespace eval ::fpga_project {
    variable settings [dict create \
        part xc7z020clg484-1 \
        top my_filter \
        clock_port aclk \
        period_ns 10.0 \
        python auto \
        rtl_files {rtl/custom/filter_impl.sv} \
        include_dirs {} \
        defines {} \
        xdc_files {}]
}
```

top은 **module 선언 이름**입니다. Tcl 목록에는 쉼표를 넣지 않습니다.
공백이 있는 경로는 `{rtl/my files/filter_impl.sv}`처럼 묶습니다.
기본 fixtures 항목은 새 TB에 적용되지 않으며 필요 없으면 삭제해도 됩니다.

```text
tb/tb_my_filter/
  tb_my_filter.sv       module tb_my_filter 선언, DUT 연결·입력·기대값 비교
  tb_my_filter.f        TB와 검증 전용 파일 목록
```

`tb_my_filter.f`에는 다음처럼 한 줄에 파일 하나를 적습니다. 경로는 이 .f가 있는 폴더 기준입니다.
RTL 목록은 project.tcl에서 관리합니다.

```text
tb_my_filter.sv
```

이후 `fpga::sim tb_my_filter`를 실행합니다. 실행기에 TB 이름을 별도로 등록하지 않습니다.
기존 ResNet TB가 다른 기능을 자동으로 검증해 주지는 않습니다. 포트만 맞추는 adapter/wrapper를 사용할 수도 있습니다.

| project.tcl 항목 | 의미 |
|---|---|
| rtl_files | 합성할 .v/.sv. package 등 의존 파일 먼저 |
| top | 최상위 module 이름 |
| clock_port / period_ns | 자동 주 클럭 포트 / 분석 목표 ns |
| part | FPGA device |
| include_dirs / defines | RTL header 폴더 / 전처리 define |
| xdc_files | 추가 클럭·I/O 제약. 자동 주 클럭과 중복 정의하지 않음 |
| python | auto 또는 실제 python.exe 경로. `{py -3}`도 가능 |

프로젝트 설정의 상대 경로는 루트 기준입니다. TB의 include 폴더는 자동 적용됩니다.
클럭 없는 조합 모듈은 `clock_port {}`로 자동 클럭을 생략합니다. Timing에는 별도 virtual clock/I/O 제약이 필요합니다.
자체 데이터로 실행하는 새 TB는 Python을 호출하지 않습니다. 기본 수치 TB의 생성기는 fixtures에 연결돼 있습니다.
IP/Block Design은 해당 생성/제약 작업도 필요합니다.

## 5. 자주 막히는 부분

| 증상 | 조치 |
|---|---|
| fpga 명령 없음 | scripts/vivado.tcl을 source |
| Python 실행 파일 없음 | 위 Python 확인 절차 또는 실제 경로 지정 |
| Pillow 없음 | `exec {*}[fpga::python_command] -m pip install Pillow` |
| 프로젝트가 이미 열림 | 저장 후 close_sim/close_project. 실행기가 자동으로 덮어쓰지 않음 |
| 파일 없음 | project.tcl은 루트 기준, TB .f는 TB 폴더 기준 확인 |
| 포트/폭 오류 | 교체한 RTL과 TB의 포트·폭·parameter 확인 |
| 숫자 불일치 | signed, 소수부, 반올림/포화, valid/지연 확인 |
| PNG 없음 | synth만 실행했는지, analyze 중 오류가 있었는지 확인 |

project.tcl은 명령 실행마다 다시 읽습니다. 실행기 코드를 교체했다면 source도 다시 합니다.
도구 회귀검사는 verification/tools/에 있습니다. 실제 Vivado 결과는 사용자 환경에서 생성됩니다.
