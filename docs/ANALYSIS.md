# 분석 가이드

[실행 가이드](GUIDE.md)에서 Tcl 명령을 실행한 뒤 결과를 아래 순서로 확인합니다.
먼저 `VERSION`을 확인해 파형의 신호와 지연 기준을 선택합니다.

## 기능 테스트

Vivado Console과 시뮬레이션 로그에서 `[ PASS ] ALL TESTS PASSED`를 확인합니다.
실패 시 최초 `$fatal`의 클럭·인덱스·기대값·실제값을 찾아 같은 시점의 파형을 확인합니다.
독립 TB는 유효 신호와 signed 값을 검사합니다. core 연결 TB는 skip 정렬, 입력 공백, reset과 Pool/GAP 그룹도 확인합니다.
전체 모델 TB는 22개 연산 레이어의 정수 기준값을 확인합니다. 보고서 실행에서는 Python이 최종 로짓 SNR의 50 dB 기준을 판정합니다.
입력은 결정적 패턴 1개입니다.

```text
build/sim/tb_relu/
  sim_tb_relu.xpr
  sim_tb_relu.sim/sim_1/behav/xsim/
    *.log   compile/elaboration/simulation 로그
    *.wdb   파형
```

## 1.2.9 보고서 저장 위치

`fpga::report`와 `fpga::analyze core`는 배치·배선 후 Setup·Hold·Pulse Width와 Utilization을 `reports/core_report.html`에 저장합니다. 브라우저에서 바로 열 수 있습니다.
타이밍 경로와 세부 자원 사용량은 `build/analysis/core/run_*/` 아래의 Vivado 원본에서 확인합니다.
`fpga::report_sim`은 전체 모델 SNR과 latency를 `reports/snr_latency.txt`에 저장합니다. [실행 가이드](GUIDE.md)

## 1.2.3 통합 보고서

`fpga::report`가 끝나면 `build/analysis/core/run_*/`의 해당 실행 폴더에서 다음 파일을 확인합니다.

| 파일 | 내용 |
| --- | --- |
| `timing/post_route.rpt` | 배치·배선 후 Timing Summary |
| `utilization/post_route.rpt` | 배치·배선 후 Utilization |
| `snr.txt` · `snr.json` | 레이어 및 최종 로짓의 SNR. JSON에는 샘플 수와 최대 절대 오차도 포함 |
| `latency.txt` | 레이어별 및 전체 추론의 입력·출력 클럭 번호와 차이 |

latency는 첫 입력을 받는 상승 에지부터 마지막 유효 출력을 읽는 상승 에지까지의 클럭 차이입니다.
`inference` 행은 stem의 첫 입력부터 FC의 마지막 출력까지이며, 레이어 사이의 테스트벤치 대기 클럭도 포함합니다.
타이밍과 Utilization은 Vivado 배치·배선 결과이고, SNR과 latency는 전체 모델 RTL 시뮬레이션 결과입니다.

## 1.2.1 이상 레이어별 SNR

`build/sim/tb_core/snr/`에 다음 파일이 생성됩니다.

| 파일 | 내용 |
| --- | --- |
| `layer_NN_actual.hex` | 명령 인덱스 `NN`의 RTL 출력. HWC 순서의 signed 16-bit Q5.10 단어 |
| `logits_actual.hex` | `OUTPUT_FRAC_BITS`로 변환한 최종 로짓 10개 |
| `scoreboard_results.txt` | 최종 로짓 샘플 수, 소수 비트 수, 정상 완료 표시 |
| `results.json` | Python에서 계산한 레이어별 SNR, 샘플 수, 최대 절대 오차와 최종 로짓 SNR |

Python은 같은 입력과 가중치로 부동소수점 추론을 실행하고, RTL의 레이어 출력을 기존 정수 기준값과 대조합니다. 출력 단어를 `2**frac_bits`로 나눈 다음 `10*log10(sum(ref²)/sum((actual-ref)²))`로 SNR을 계산합니다. 오차 전력이 0이면 JSON에 `"inf"`를 기록합니다. 마지막 블록의 레이어 출력은 GAP 이후의 채널 벡터입니다. Python은 최종 로짓에 기존 50 dB 기준을 적용합니다. 중간 레이어 SNR은 진단용입니다.

## 타이밍과 Utilization

`build/analysis/<top>/latest.txt`에서 마지막으로 완료된 실행 경로를 찾습니다.
`run_info.tcldict`, `clock.xdc`, `sources/`에서 측정 조건을 확인합니다.

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

| 항목 | 확인 방법 |
| --- | --- |
| Setup | `timing/post_route.rpt`에서 WNS ≥ 0, TNS = 0, 위반 endpoint 0 |
| Hold | 같은 파일에서 WHS ≥ 0, THS = 0, 위반 endpoint 0 |
| Pulse Width | 같은 파일에서 WPWS ≥ 0, TPWS = 0, 위반 endpoint 0 |
| 제약·배선 | `post_route_check_timing.rpt`, `post_route_route_status.rpt`, `post_route_drc.rpt` |
| 경로 | setup/hold 상세 보고서에서 시작점, 끝점, 클럭, 논리 지연과 배선 지연 확인 |
| 전체 자원 | `utilization/post_route.rpt`에서 LUT, FF, BRAM, DSP의 사용량·가용량·비율 확인 |
| 계층별 자원 | `utilization/post_route_hierarchical.rpt`에서 core 내부 인스턴스별 사용량 확인 |

합성 직후와 배치·배선 후 변화를 보려면 같은 실행의 `post_synth.rpt`와 `post_route.rpt`를 비교합니다.
버전 비교에서는 같은 top·FPGA part·Vivado 버전·클럭 주기·제약을 사용합니다.
단독 모듈의 자원은 통합 시 최적화 조건에 따라 달라질 수 있으므로 core 전체 자원은 core top의 보고서에서 확인합니다.
OOC 결과의 판정 범위는 분석 대상과 적용된 제약입니다. 보드 전체 타이밍은 시스템 입출력·reset·추가 클럭까지 제약한 결과로 판정합니다.

[버전별 100 MHz 실측 이미지와 비교표](../reports/README.md)

## 파형 공통 기준

E0은 입력을 수신하는 상승 에지이며 출력은 해당 에지의 레지스터 갱신 직후 기준입니다.

| 항목 | 1.0.0 | 1.1.0~1.2.3 |
| --- | --- | --- |
| MAC | 2단계 | 5단계 |
| GAP | 2단계, 양수 N, 가변 나눗셈 | 4단계, 기본 1·2·4·…·1024, shift |
| skip 정렬 | main과 skip 각각 1개 보관 | 4-entry skip FIFO와 main 1개 보관 |
| 전체 우회 | E0 입력 → E9 출력 → E10 소비 | E0 입력 → E14 출력 → E15 소비 |

| 신호/조건 | 정상 동작 | 확인 이유 |
|---|---|---|
| clk, nrst | 상승 에지 수신, nrst=0에서 valid와 카운터 초기화 | 입력 기준과 중간 취소 확인 |
| enable | 1이면 해당 연산, 0이면 같은 파이프라인 지연으로 우회 | 비활성 블록도 연결 지연을 유지하는지 확인 |
| in_enable, in_data | in_enable=1인 상승 에지에서만 입력을 수신 | 입력 공백을 데이터로 잘못 세지 않는지 확인 |
| out_enable, out_data | out_enable=1인 구간의 데이터만 비교 | valid=0인 데이터의 X/이전 값은 의미 없음 |
| enable, iteration 설정 | 첫 입력 전부터 모든 출력이 배출될 때까지 고정 | 진행 중인 그룹/파이프라인 해석이 바뀌지 않도록 함 |

- Signed Decimal: in_data, kernel_data, bias_data, skip_data, 곱/누산의 signed 값, 최종 출력.
- Unsigned Decimal: 카운터, shift, 절댓값과 반올림 후 magnitude.
- Q5.10 입출력은 저장 정수/1024가 실수 값입니다. 예: 1024=1.0, -1024=-1.0.
- MAC product/accumulator/s1_sum은 기본 Q20입니다. 입출력과 같은 배율로 읽으면 안 됩니다.
- 입력 valid=0이 되어도 이전 결과는 뒤에서 계속 배출됩니다.
- N=1이나 연속 우회 입력에서는 out_enable이 여러 클럭 연속 1일 수 있습니다. 유효한 상승 에지마다 한 결과입니다.
- MAC/GAP의 일부 데이터 레지스터는 reset하지 않습니다. reset 중 또는 valid=0일 때 X가 보여도 그 자체로 실패는 아닙니다.



scripts/vivado.tcl을 source한 뒤 Vivado Tcl Console에서 실행합니다.

| 대상 | 실행 명령 | 내부 DUT 경로 |
|---|---|---|
| bias 없는 MAC | fpga::test mac | /tb_mac/g_unit_0/u_mac/u_accumulate/ |
| bias 있는 MAC(core와 같은 연산부) | fpga::test mac | /tb_mac/g_unit_1/u_biased_mac/ |
| Residual | fpga::test residual | /tb_residual/g_unit_2/u_residual/ |
| ReLU | fpga::test relu | /tb_relu/g_unit_3/u_relu/ |
| MaxPool | fpga::test pooling | /tb_pooling/g_unit_4/u_pooling/ |
| GAP | fpga::test general_average_pooling | /tb_general_average_pooling/g_unit_5/u_gap/ |
| core 연결 | fpga::test core | /tb_core_stream/dut/ |

다른 생성 프로젝트가 열려 있다면 fpga::finish 후 다음 테스트를 실행합니다.
기본 화면에는 TB 신호가 표시됩니다. 내부 신호도 보려면 테스트 후 다음처럼 추가합니다.

```tcl
fpga::finish
fpga::test core
add_wave -r /tb_core_stream/dut/*
```

```tcl
# MAC 테스트를 실행한 상태
add_wave -r /tb_mac/g_unit_1/u_biased_mac/*
```

```tcl
# GAP 테스트를 실행한 상태
add_wave -r /tb_general_average_pooling/g_unit_5/u_gap/*
```

실행기는 run all 전에 하위 신호도 재귀적으로 log_wave합니다.
파형 화면에서 필요한 신호만 남기고 한 그룹의 입력~출력 구간을 확대합니다.

독립 TB의 기준값 신호: ev[i]는 현재 기대 valid, ed[i]는 기대 저장 정수입니다.
result_valid[i]/result_data[i]와 비교합니다. 인덱스는 MAC=0, bias MAC=1, Residual=2, ReLU=3, Pool=4, GAP=5입니다.
core TB는 expected[], expected_due[], queued, received, cycle을 함께 볼 수 있습니다.
expected_due=-1인 항목은 출력 순서/값을 검사하고 정확한 출력 클럭은 지정하지 않은 경우입니다.

## 1.0.0 모듈별 파형

### MAC: mac.v / mac_accumulate

| 신호 | 정상 동작 | 확인 이유 |
|---|---|---|
| input_count, iteration, in_enable | 유효 N항만 계산, 마지막 항 후 0 | 그룹 경계와 공백 처리 |
| last_input | 마지막 항 수신 에지 직전에 1 | 최종 합을 내보내는 경계 |
| product, product_ext | in_data*kernel_data와 부호 확장 | signed 곱/폭 확인 |
| bias_ext, base_sum, accumulator, total | 첫 항은 bias<<10, 이후는 부분합부터 누산 | 첫 bias만 적용, 마지막 곱 포함 |
| pending_enable, pending_data | 마지막 항 E0에 round_shift()/saturate() 결과 보관 | 반올림과 포화 확인 |
| out_enable, out_data | E1 직후 출력 | 두 레지스터의 데이터/valid 정렬 |

N=2, 입력/가중치가 모두 1024, 첫 bias=1024이면 out_data=3072입니다.
두 번째 bias를 바꿔도 해당 그룹 결과가 같아야 합니다. 큰 양/음수에서 32767/-32768로 포화하는지 확인합니다.
enable=0이면 두 단계 우회, 활성 iteration=0이면 입력 폐기와 부분합 초기화입니다.
1.0.0은 마지막 항에서 곱셈·누산·반올림·포화가 긴 조합 경로로 연결됩니다.
behavioral 값이 맞아도 실제 100MHz 타이밍이 맞는 것은 아닙니다.

### Residual: residual.v

| 확인 신호 | 정상 동작 | 이유 |
|---|---|---|
| in_enable, in_data, skip_data | 같은 수신 에지에서 main/skip 사용 | 서로 다른 위치/채널 데이터가 섞이는지 추적 |
| main_ext, skip_ext | 각각 한 비트 부호 확장 | signed overflow 판정에 필요한 17비트 합 확인 |
| pending_enable, pending_data | E0에서 포화 합 또는 우회 값 등록 | 1단계 연산 확인 |
| out_enable, out_data | E1 직후 결과 유효 | valid/데이터 지연 일치 확인 |

확인 예: 1024+512→1536, 32760+20→32767, -32760-20→-32768.
enable=0이면 skip_data와 관계없이 in_data를 전달합니다.
공간/채널 정합은 외부의 책임이며, 이 모듈은 받은 두 값의 합만 계산합니다.

### ReLU: relu.v

| 확인 신호 | 정상 동작 | 이유 |
|---|---|---|
| enable, in_data[15], in_enable | 활성+음수일 때 0 선택 | 부호 비트와 enable 조건 확인 |
| pending_enable, pending_data | E0에서 0 또는 입력값 등록 | 음수 제거 연산 확인 |
| result_valid, result_data, out_enable, out_data | E1 직후 출력 유효 | valid/데이터 전달 확인 |

확인 예: enable=1에서 -1024→0, 0→0, 1024→1024. enable=0에서는 -1024도 그대로 전달합니다.

### MaxPool: pooling.v

| 확인 신호 | 정상 동작 | 이유 |
|---|---|---|
| iteration, in_enable, input_count | N개 유효 입력마다 그룹 완료 | 공백을 제외한 창 크기 확인 |
| maximum, next_maximum | 첫 항으로 시작해 signed 최대값 선택 | 모두 음수인 창도 정상인지 확인 |
| pending_enable, pending_data | N번째 입력 E0에 최종 최대값 등록 | 마지막 항도 비교에 포함하는지 확인 |
| out_enable, out_data | E1 직후 해당 창의 결과 출력 | 출력 개수/지연 확인 |

확인 예: N=4, [-5,-2,-7,-9]→-2. 마지막 항이 가장 큰 창도 검사합니다.
마지막 항 에지에 maximum과 input_count는 0으로 초기화될 수 있으므로 결과는 pending_data/out_data에서 확인합니다.
iteration=0은 입력 폐기, enable=0은 2단계 우회입니다.

### GAP: general_average_pooling.v

| 신호 | 정상 동작 | 확인 이유 |
|---|---|---|
| iteration, in_enable, input_count | 기본 16비트 포트의 양수 N개를 수신 | 그룹 크기와 공백 제외 확인 |
| accumulator, input_ext, total | signed 합산, 마지막 항까지 포함 | 평균의 분자 확인 |
| pending_enable, pending_sum, pending_divisor | N번째 입력 E0에 합/N 보관 | 합과 분모가 같은 그룹인지 확인 |
| out_enable, out_data | round_mean()의 반올림 평균을 E1 직후 출력 | 출력 시점과 양/음 반올림 확인 |

N=3도 지원합니다. [3,6,9]→6, N=2에서 [-1,0]→-1, [1,0]→1을 확인합니다.
iteration=0은 입력 폐기/부분합 초기화이며, enable=0은 두 단계 우회입니다.
round_mean() 내부는 함수의 지역 변수이므로 파형 노출 여부는 시뮬레이터에 따라 다릅니다.
pending_sum/pending_divisor/out_data를 기준으로 비교하십시오.
1.0.0에는 supported/input_shift/half/s0_sum 같은 1.1.0의 신호가 없습니다.

### core.v: 단계 연결과 main/skip 보관

| 신호 | 정상 동작 | 확인 이유 |
|---|---|---|
| 각 *_valid/*_data | MAC→Residual→ReLU→Pool→GAP로 유효 값 전달 | 최초 오류 발생 단계 찾기 |
| mac_last_input, waiting_for_skip | 마지막 MAC 항 뒤 skip 대기 | 입력의 역할 구분 |
| skip_valid, u_mac/in_enable | skip 수신 시 MAC 입력 valid=0 | skip이 곱셈에 섞이지 않도록 확인 |
| mac_held_valid/data | 먼저 온 MAC 결과를 skip까지 보관 | 늦은 skip 처리 |
| skip_held_valid/data | 먼저 온 skip을 MAC 결과까지 보관 | 이른 skip 처리 |
| pair_valid, residual_main, residual_skip | 같은 그룹의 main/skip을 함께 전달 | 잔차의 순서/정렬 확인 |
| gap_valid/gap_data, out_enable/out_data | 동일한 valid/값 | 최종 연결 확인 |

mac_held_valid/data는 mac_held_valid와 mac_held_data, skip_held_valid/data는 skip_held_valid와 skip_held_data를 뜻합니다.
use_residual=mac_enable&&residual_enable이며, MAC 우회에서는 Residual도 우회합니다.
이 버전에는 skip_push/pop/count/FIFO가 없습니다.

모든 연산을 우회하고 E0에 값 1024를 한 번 수신한 경우:

| 에지 직후 | 신호 | 값 |
|---|---|---|
| E1 | mac_valid/mac_data | 1/1024 |
| E3 | residual_valid/residual_data | 1/1024 |
| E5 | relu_valid/relu_data | 1/1024 |
| E7 | pooling_valid/pooling_data | 1/1024 |
| E9 | gap_valid/gap_data, out_enable/out_data | 1/1024 |

E9 직후 유효해지고 수신측은 E10에서 소비합니다.
Pool/GAP 우회에서 마지막 MAC 항이 L, skip 수신이 S이면:
- Residual 비활성: L+9 직후 출력.
- Residual 활성: max(L+2,S)+7 직후 출력.

빠른 skip/늦은 skip/연속 그룹/입력 공백/reset 중간 취소를 확인합니다.
Pool/GAP 활성에서는 그룹을 모으므로 입력마다 최종 출력이 생기지 않습니다.

## 1.1.0~1.2.3 모듈별 파형

### MAC: mac.v / mac_accumulate

| 확인 신호 | 정상 동작 | 이유 |
|---|---|---|
| in_enable, iteration, input_count | 활성 N항의 수신 횟수만 계산, 마지막 항 후 0 | 그룹 경계와 off-by-one 확인 |
| last_input, s0_last | 마지막 항 수신 에지에 마지막 표시, s0_last로 등록 | 최종 합이 한 번만 출력되는지 확인 |
| s0_first, s0_bias | 첫 항 표시와 bias를 데이터와 함께 전달 | 첫 항 bias만 실제 합에 적용되는지 확인 |
| s0_product | 유효 입력을 받은 에지에 in_data*kernel_data 등록 | 곱셈의 부호/폭과 입력 대응 확인 |
| accumulator, s1_sum | 한 클럭 뒤 누산, 마지막 항에서 최종 합 보관 | 마지막 곱 누락·중복 누산 확인 |
| s2_magnitude, s2_negative | 최종 합의 절댓값/부호 | 음수와 최솟값 처리 확인 |
| s3_rounded, s3_negative | Q20→Q10 반올림, 부호 동행 | 양/음의 절반 반올림 확인 |
| s0_valid, s1_valid, s2_valid, s3_valid, out_enable | s0은 각 항, s1 이후는 완료 결과/우회 값만 전달 | 항 valid와 결과 valid를 구분 |
| out_data | signed INT16로 포화된 최종 값 | overflow가 부호 반전으로 나타나지 않는지 확인 |

마지막 MAC 항이 E0이면 S0=E0 → S1=E1 → S2=E2 → S3=E3 → out=E4입니다.
last_input은 조합 신호이므로 수신 에지 직전 값 또는 등록된 s0_last로 마지막 항을 판단합니다.
입력 공백 에지에 accumulator가 갱신될 수 있습니다. 이전 에지의 곱이 S1로 도착한 경우 정상입니다.
완료 후 accumulator가 0으로 지워질 필요는 없습니다. 다음 그룹의 첫 항이 bias+product로 새 합을 시작합니다.

확인 예:
- N=2, 두 입력/가중치가 모두 1024, 첫 항 bias=1024이면 최종 out_data=3072.
- 두 번째 항의 bias를 바꿔도 해당 그룹 결과는 같아야 합니다.
- N=1, in_data=32767, kernel_data=32767, bias=0이면 출력은 32767로 포화합니다.
- enable=0이면 입력과 같은 값이 동일한 5단계 지연으로 출력됩니다.

### Residual: residual.v

| 확인 신호 | 정상 동작 | 이유 |
|---|---|---|
| in_enable, in_data, skip_data | 같은 수신 에지에서 main/skip 사용 | 서로 다른 위치/채널 데이터가 섞이는지 추적 |
| main_ext, skip_ext | 각각 한 비트 부호 확장 | signed overflow 판정에 필요한 17비트 합 확인 |
| pending_enable, pending_data | E0에서 포화 합 또는 우회 값 등록 | 1단계 연산 확인 |
| out_enable, out_data | E1 직후 결과 유효 | valid/데이터 지연 일치 확인 |

확인 예: 1024+512→1536, 32760+20→32767, -32760-20→-32768.
enable=0이면 skip_data와 관계없이 in_data를 전달합니다.
공간/채널 정합은 외부의 책임이며, 이 모듈은 받은 두 값의 합만 계산합니다.

### ReLU: relu.v

| 확인 신호 | 정상 동작 | 이유 |
|---|---|---|
| enable, in_data[15], in_enable | 활성+음수일 때 0 선택 | 부호 비트와 enable 조건 확인 |
| pending_enable, pending_data | E0에서 0 또는 입력값 등록 | 음수 제거 연산 확인 |
| result_valid, result_data, out_enable, out_data | E1 직후 출력 유효 | valid/데이터 전달 확인 |

확인 예: enable=1에서 -1024→0, 0→0, 1024→1024. enable=0에서는 -1024도 그대로 전달합니다.

### MaxPool: pooling.v

| 확인 신호 | 정상 동작 | 이유 |
|---|---|---|
| iteration, in_enable, input_count | N개 유효 입력마다 그룹 완료 | 공백을 제외한 창 크기 확인 |
| maximum, next_maximum | 첫 항으로 시작해 signed 최대값 선택 | 모두 음수인 창도 정상인지 확인 |
| pending_enable, pending_data | N번째 입력 E0에 최종 최대값 등록 | 마지막 항도 비교에 포함하는지 확인 |
| out_enable, out_data | E1 직후 해당 창의 결과 출력 | 출력 개수/지연 확인 |

확인 예: N=4, [-5,-2,-7,-9]→-2. 마지막 항이 가장 큰 창도 검사합니다.
마지막 항 에지에 maximum과 input_count는 0으로 초기화될 수 있으므로 결과는 pending_data/out_data에서 확인합니다.
iteration=0은 입력 폐기, enable=0은 2단계 우회입니다.

### GAP: general_average_pooling.v

| 확인 신호 | 정상 동작 | 이유 |
|---|---|---|
| iteration, supported, input_shift | 기본 N=1,2,4,…,1024일 때 supported=1, shift=log2(N) | 지원 크기와 제어 인코딩 확인 |
| in_enable, input_count, accumulator | 유효 입력만 합산, 첫 항부터 새 합 시작 | 채널별 합/그룹 경계 확인 |
| last_input, s0_valid, s0_sum, s0_shift | N번째 입력 E0에 최종 합과 shift 저장 | 마지막 값 포함·분모 대응 확인 |
| s1_valid, s1_magnitude, s1_negative, s1_shift | E1에 절댓값/부호/shift 동행 | 음수 반올림 준비 확인 |
| half, rounded_magnitude, s2_valid, s2_rounded, s2_negative | E2에 반올림한 magnitude 등록 | 단순 버림과 구분, 부호 지연 확인 |
| out_enable, out_data | E3 직후 부호를 복원한 평균 | 출력 지연/수치 확인 |

확인 예:
- N=4, [1024,2048,3072,4096]이면 s0_sum=10240, shift=2, half=2, out_data=2560.
- N=2, [-1,0]→-1, [1,0]→1: 저장 정수의 정확한 절반은 0에서 먼 방향으로 반올림합니다.
- N=3 또는 N=2048이면 supported=0. 기존 파이프라인 결과가 배출된 뒤 새 유효 출력은 없어야 합니다.
- enable=0이면 N의 지원 여부와 관계없이 입력을 4단계로 우회합니다.
완료 후 accumulator 값이 남아 있어도 정상입니다. 다음 그룹의 첫 항은 input_count=0을 보고 새 합으로 덮어씁니다.

### core.v: 단계 연결과 skip 정렬

1.2.2 이상에서는 core DUT 아래의 `u_conv`에서 MAC 결과와 skip 정렬 신호를 확인합니다.
MAC 내부 경로는 `/tb_core_stream/dut/u_conv/u_mac/`입니다. 아래 표의 `mac_*`, `skip_*`, `waiting_for_skip`, `pair_valid`는 `u_conv` 내부 신호입니다.
1.1.0~1.2.1에서는 동일한 신호를 core DUT 바로 아래에서 확인합니다.

우선 다음을 한 화면에서 봅니다.

```text
clk, nrst
mac_enable, mac_iteration, residual_enable, relu_enable
pooling_enable, pooling_iteration, gap_enable, gap_iteration
in_enable, in_data, kernel_data, bias_data
mac_valid/mac_data
residual_valid/residual_data
relu_valid/relu_data
pooling_valid/pooling_data
gap_valid/gap_data
out_enable/out_data
```

| 구간 | 정상 동작 | 이유 |
|---|---|---|
| 각 *_valid / *_data | 유효한 값만 다음 단계가 수신 | 데이터 오류가 처음 생기는 블록 찾기 |
| use_residual | mac_enable && residual_enable | MAC 우회에서는 residual도 우회하는 규약 확인 |
| mac_last_input → waiting_for_skip | 마지막 MAC 항 수신 후 skip 대기 | 입력을 MAC 항과 skip으로 분리하는지 확인 |
| skip_valid, u_mac/in_enable | skip 수신 때 skip_valid=1, MAC 입력 valid=0 | skip을 다음 MAC 곱으로 잘못 넣지 않는지 확인 |
| skip_push/pop, skip_count, skip_read/write, skip_fifo | 먼저 온 skip을 FIFO 순서대로 보관/소비 | 연속 그룹에서 덮어쓰기·순서 변경 검출 |
| mac_held_valid, mac_held_data | skip이 늦으면 MAC 결과 보관 | 입력 공백 동안 결과가 사라지지 않는지 확인 |
| pair_valid, residual_in_valid, residual_main, residual_skip | main과 해당 skip이 모두 준비되면 한 쌍 전달 | 다른 그룹의 main/skip 혼합 검출 |
| gap_valid/gap_data, out_enable/out_data | 각각 같은 값 | 최종 출력 연결 확인 |

skip_push와 skip_pop이 동시에 1이면 skip_count가 유지되는 것이 정상입니다.
FIFO가 비어 있고 main/skip이 동시에 준비되면 직접 전달하여 skip_count가 증가하지 않을 수 있습니다.
현재 FIFO 깊이는 4이며 overflow와 보관 MAC 덮어쓰기는 시뮬레이션 assertion으로도 검사합니다.

#### 전체 우회 시 기준 타이밍

모든 연산 enable=0, E0에 입력 1024를 한 번 수신한 경우입니다.

| 상승 에지 직후 | 관찰 신호 | 값 |
|---|---|---|
| E0 | in_enable로 입력 수신 | 1024 |
| E4 | mac_valid/mac_data | 1 / 1024 |
| E6 | residual_valid/residual_data | 1 / 1024 |
| E8 | relu_valid/relu_data | 1 / 1024 |
| E10 | pooling_valid/pooling_data | 1 / 1024 |
| E14 | gap_valid/gap_data, out_enable/out_data | 1 / 1024 |

출력은 E14 직후 유효해지고 다음 상승 에지 E15에서 수신측이 소비합니다.

#### skip이 빠른 경우와 늦은 경우

MAC N=1, 입력 1024, 가중치 1024, bias=0, skip=512, Pool/GAP 우회 예입니다.

- 마지막 MAC 항을 E0, skip을 E1에 수신: skip FIFO 보관 → E5에 pair 소비 → E14 직후 최종 1536.
- 마지막 MAC 항을 E0, skip을 E10에 수신: MAC 결과 보관 → E10에 pair 소비 → E19 직후 최종 1536.

일반적으로 마지막 MAC 입력이 L, skip 입력이 S이면 Pool/GAP 우회에서:
- residual 비활성: L+14 직후 출력.
- residual 활성: max(L+5,S)+9 직후 출력.

N=1의 MAC/skip 쌍을 연속 공급하는 구간에서는 FIFO 포인터가 순환해도 출력 순서가 유지되는지 확인합니다.
Pool/GAP를 활성화하면 각각의 반복값만큼 결과가 모이므로 입력 하나마다 최종 출력이 생기지 않습니다.

### 권장 확인 순서

1. reset: valid/카운터 초기화와 진행 중 결과 취소.
2. 전체 우회: 값 보존과 E0→E14 정렬.
3. MAC 단독: 곱, 첫 항 bias, 그룹 경계, 반올림/포화.
4. Residual: 이른 skip, 늦은 skip, 연속 MAC/skip 쌍.
5. ReLU: 양수/0/음수 및 우회.
6. Pool: 창 크기, 음수 최대값, 마지막 항 최대값.
7. GAP: 지원 N, 합/shift, 양·음 반올림, 비지원 N 폐기.
8. 전체 연결: 각 단계 valid/값의 순서, 총 출력 수, TB의 ALL TESTS PASSED.

Behavioral waveform은 기능과 클럭별 정렬을 확인합니다.
100MHz의 실제 setup/hold 충족 여부는 배치배선 후 Timing Report로 별도 확인합니다.
