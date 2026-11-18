# Core 검증 방법

모든 검증은 실제 `rtl/compute/`의 6개 파일을 사용합니다. 참고 RTL로 우회하지 않습니다.

| 검사 | Vivado 실행 명령 | 검사 내용 |
|---|---|---|
| 하위 모듈 | `core_sim::launch tb_modules` | MAC/bias/Add/ReLU/Max/AVG 값과 매 클럭 valid |
| Core 연결 | `core_sim::launch tb_core_stream` | 연속 입력·공백·skip 지연·Pool/GAP 조합·reset 복구 |
| 전체 모델 | `core_sim::launch tb_core` | 첨부 ResNet-20의 22개 affine 레이어 정수 정답과 로짓 SNR |

세 TB는 모두 `tb/<이름>/<이름>.sv`와 같은 폴더의 `<이름>.f`를 사용합니다.
Tcl의 이름과 Simulation Top은 해당 `<이름>`으로 같습니다.
`core_sim::launch tb_modules.sv`처럼 파일명을 지정해도 됩니다.

README의 source 절차를 사용합니다. 다음 TB로 바꾸기 전 `close_sim -force`, `close_project`를 실행합니다.
Python이 PATH에 없으면 launch의 두 번째 인자로 실행 파일을 지정합니다.

## 하위 모듈 검사

Python `generate_unit_vectors.py`가 독립 정수 연산으로 기대값/출력 시점을 생성합니다.
기본 WORD_W=16/FRAC_W=10. bias 1회 적용, ±tie/포화, signed 최솟값, 모두 음수인 Max,
1/2/3/9/31/64/576/1023/65535회 그룹, 공백, 부분 작업 reset, iteration=0 복구를 포함합니다.
`tb_modules.sv`는 실제 여섯 인스턴스를 직접 구동합니다.

## 전체 모델 검사

`generate_resnet20_core.py`는 첨부 weight.bin으로 float 기준값과 독립 정수 레이어 정답을 생성합니다.
`quantized_reference.py`는 Python의 임의 정밀도 정수로 MAC/포화/Residual/ReLU/GAP를 계산합니다.
TB는 매 레이어 모든 출력값을 정수 비교한 뒤 마지막 로짓 SNR>=50dB를 검사합니다.
이 fixture는 32×32×3 테스트 패턴 1개이며 실제 이미지 데이터셋 정확도 검증은 아닙니다.

기존 Windows/Bash 실행기도 같은 실제 RTL을 사용합니다. 입력 공백과 skip 지연을 바꾸려면:

```bat
set INPUT_GAP=2
scripts\behav_sim.bat tb_core --skip-delay 4
```

```bash
INPUT_GAP=2 bash scripts/behav_sim.sh tb_core --skip-delay 4
```

## 파형에서 확인할 신호

| 위치 | 확인 |
|---|---|
| dut/u_mac | input_count, accumulator, pending_enable, out_enable. 첫 항에만 bias 적용 |
| dut | waiting_for_skip, mac_held_valid, skip_held_valid, pair_valid. skip을 MAC에 넣지 않음 |
| dut/u_residual | 정렬된 main/skip 합, 포화 |
| dut/u_relu | 음수 제거와 비활성 우회 |
| dut/u_pooling | input_count와 maximum. 첫 항은 음수여도 채택 |
| dut/u_gap | accumulator, pending_sum, pending_divisor, out_enable |

데이터는 Signed Decimal로 표시합니다. `in_enable=1`인 매 상승 에지가 입력 수신입니다.
출력은 `out_enable=1`일 때만 읽습니다. ready/done 포트는 없으므로 이전 버전의 신호명을 사용하지 않습니다.

## 합성 이후

`scripts/synthesis.bat tb_core` 또는 `bash scripts/synthesis.sh tb_core`는 실제 core를 OOC 합성합니다.
대상은 xc7z020clg484-1, 클럭 목표는 10ns입니다. 결과 폴더의 utilization/timing_summary를 확인합니다.
이 스크립트는 합성 단계이며 배치배선/bitstream/보드 실행은 포함하지 않습니다.
post-synthesis 검증도 원본 RTL 대신 **compute/core_funcsim.v**를 읽습니다.

GAP 조합 divider가 critical path인지, DSP/LUT/FF가 예산 안인지 확인합니다.
보드 전체 타이밍은 Controller/메모리/top을 완성한 뒤 실제 I/O·reset 제약으로 별도 확인합니다.
실제 실행한 도구와 범위는 [검증 기록](../verification/core/results/README.md)에 구분해 기록합니다.

Timing/Utilization PNG와 배치배선은 별도 [분석 흐름](CORE_ANALYSIS.md)을 사용합니다.

## No projects are currently open 오류

`core_sim::launch`는 프로젝트가 없는 상태에서 실행해 검증 프로젝트를 생성합니다.
일부 Vivado에서 `current_project -quiet`도 Coretcl 2-88 오류를 내므로 실행기에서 이를 처리했습니다.
최신 `scripts/validate_core.tcl`로 교체한 뒤 **source를 다시 실행**하고 launch하십시오.
기존 proc가 메모리에 남아 있으므로 파일 교체만으로는 적용되지 않습니다.
수동으로 빈 프로젝트를 만들 필요는 없습니다.

파일 배치가 맞는지 확인하려면 프로젝트 루트에서 `python verification/core/check_paths.py`를 실행합니다.
이 검사는 실제 파일·module 선언·.f 경로·문서의 Tcl 대상 이름을 대조하며 Vivado가 필요하지 않습니다.
