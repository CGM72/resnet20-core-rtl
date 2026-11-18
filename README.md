# ResNet-20 Core — 첨부 양식 기반 구현

[전체 프로젝트 ZIP 다운로드](https://github.com/CGM72/resnet20-core-rtl/raw/refs/heads/main/downloads/resnet20-core-rtl.zip)

`rtl/compute/core.sv`와 5개 하위 모듈을 실제 합성 가능한 RTL로 구현했습니다.
이전 명령형 SIMD 설계는 사용하지 않고, 첨부의 **단일 lane · signed INT16 · Q5.10 · valid-only 포트**를 유지했습니다.
Controller/AXI/DMA/메모리 주소 제어는 별도 구현 대상입니다.

```text
core.sv
  MAC → Residual → ReLU → MaxPool → GAP → out_data
   └─ 마지막 MAC 항 다음의 유효 in_data를 skip으로 분리·정렬
```

| 실제 파일 | 역할 |
|---|---|
| rtl/compute/core.sv | 5개 연산 모듈 연결과 MAC/skip 시간 정렬 |
| rtl/compute/mac.v | 단일 곱셈/넓은 누산, 첫 항 bias, 반올림/포화. mac_accumulate가 core 연산부 |
| rtl/compute/residual.v | 같은 Q scale의 main+skip 합과 포화 |
| rtl/compute/relu.v | 음수 제거 / 우회 |
| rtl/compute/pooling.v | N개 유효 입력의 signed 최대값 |
| rtl/compute/general_average_pooling.v | N개 유효 입력의 반올림 평균 |
| tb/tb_modules/ | 실제 하위 모듈의 수치·출력 타이밍 검사 |
| tb/tb_core_stream/tb_core_stream.sv | skip 지연, 연속 입력, Pool/GAP 조합, reset 복구 검사 |
| tb/tb_core/ | 첨부 ResNet-20 전체 실행과 22개 affine 레이어 정수 정답 비교 |

## 연결 규약

- `in_enable=1`인 **매 상승 에지**에 입력을 수신합니다. ready는 없습니다.
- 설정은 작업 시작 전부터 모든 결과가 배출될 때까지 유지합니다.
- `mac_iteration=N`: N쌍의 feature/weight를 공급합니다. bias는 첫 항에서만 사용합니다.
- residual 활성 시: N개 MAC 항 다음의 **유효 입력 1개**가 skip입니다. skip 에지의 kernel/bias는 무시합니다.
- `out_enable=1`인 매 에지에 출력을 받습니다. 외부에서 결과를 정지시킬 수 없습니다.
- MAC/Pool/GAP가 비활성이면 해당 단계는 우회합니다. 각 단계는 우회 시에도 2개 레지스터를 거칩니다.
- 활성 반복값 0은 입력을 폐기하고 해당 모듈의 부분 그룹을 지웁니다. 정상 작업에는 1 이상을 사용합니다.
- `PARALLEL_PC=PARALLEL_PF=1`만 지원합니다. scalar 포트를 유지했으므로 다른 값은 elaboration 오류로 거부합니다.

## Vivado GUI 검증

| Tcl 인자 / Simulation Top | 실제 TB / 파일 목록 |
|---|---|
| tb_modules | tb/tb_modules/tb_modules.sv / tb_modules.f |
| tb_core_stream | tb/tb_core_stream/tb_core_stream.sv / tb_core_stream.f |
| tb_core | tb/tb_core/tb_core.sv / tb_core.f |

`core_sim::launch tb_modules.sv`처럼 실제 파일명을 넣어도 같은 TB를 실행합니다.
RTL top은 `rtl/compute/core.sv`의 `core`이며, TB top은 위 이름을 사용합니다.

Vivado Tcl Console에서 **프로젝트의 실제 경로**로 source합니다. 열린 프로젝트는 저장하고 닫습니다.
Git clone 폴더와 ZIP의 최상위 폴더를 모두 `resnet20-core-rtl`로 통일했습니다.

```tcl
source {C:/Users/idec/Desktop/Chae/Project_ResNet/codes/resnet20-core-rtl/scripts/validate_core.tcl}
core_sim::launch tb_modules
```

최종 `[ PASS ] ALL TESTS PASSED`를 확인하고 다음 검사를 실행합니다.

```tcl
close_sim -force
close_project
core_sim::launch tb_core_stream
# PASS 확인 후
close_sim -force
close_project
core_sim::launch tb_core
```

tb_modules/tb_core 실행기는 Python 3.10+로 기대 데이터를 자동 생성합니다. Python 경로를 지정할 수도 있습니다.

```tcl
core_sim::launch tb_modules {C:/Python312/python.exe}
```

`close_sim -force`는 변경된 파형 설정을 저장하지 않고 종료합니다.
전체 모델은 단일 MAC으로 수천만 입력 클럭을 실행하므로 모듈 검사보다 오래 걸립니다.

## 기존 실행 방식

Vivado bin과 Python 3.10+를 PATH에 넣고 프로젝트 루트에서 실행합니다.

```bat
scripts\behav_sim.bat tb_core
scripts\synthesis.bat tb_core
scripts\synthesis.bat tb_core --sim
```

```bash
bash scripts/behav_sim.sh tb_core
bash scripts/synthesis.sh tb_core
bash scripts/synthesis_sim.sh tb_core
```

이제 behavioral/합성/post-synthesis 모두 **rtl/compute 구현**을 사용합니다.
`verification/core/reference_rtl`은 첨부의 비교 자료이며 실제 검증 대상으로 연결하지 않습니다.
합성 결과: `build/synth/tb_core/zedboard/compute/`. OOC clock 목표는 10ns입니다.
보드 pin XDC는 core 단독 합성에 적용하지 않고 `core_ooc.xdc`의 clock 제약만 사용합니다.
`--output-frac-bits`는 TB의 최종 로짓 출력 형식이며 하드웨어 내부 기본 Q5.10을 바꾸지 않습니다.

## 검증 범위

첨부 네트워크는 **BasicBlock 기반 ResNet-20**입니다. core 자체는 MAC 항 수를 바꾸어 Conv/FC에 재사용합니다.
입력 fixture는 CIFAR-10 크기 32×32×3의 결정적 테스트 패턴이며 실제 CIFAR-10 사진/정확도 평가가 아닙니다.
각 레이어의 Python 정수 정답 일치와 float 대비 최종 로짓 SNR을 확인합니다.

- [구조·수치·타이밍](docs/architecture.md)
- [검증 방법과 파형](docs/CORE_VALIDATION.md)
- [실제 실행 기록](verification/core/results/README.md)

Controller/top/AXI 영역은 첨부의 미완성 상태를 유지했습니다. core 검증 PASS가 전체 보드 동작을 뜻하지 않습니다.
