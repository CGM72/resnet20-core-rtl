# general_average_pooling.v 선언 사전 — 1.1.1

[모듈 목록·읽는 법](README.md) · [실제 RTL](../../rtl/compute/general_average_pooling.v) · [파형 확인](../waveforms/v1.1.0.md)

같은 채널의 N개 공간 값을 합산해 반올림 평균 하나를 만든다. 입출력 Q scale은 같다.

```text
유효 입력 합산 → E0: s0_sum → E1: 절댓값 → E2: 반올림/shift → E3: 부호 복원/출력
```

표의 비트 수·상수 값은 기본 파라미터 기준입니다. `parameter`는 외부 설정, `localparam`은 내부에서 정해지는 상수입니다.
E0은 입력 수신 상승 에지이며, 출력 시점은 해당 에지의 레지스터 갱신 직후입니다.

## 모듈 `general_average_pooling`

### 설정 파라미터

| 선언 이름 | 선언 종류·기본 폭/값 | 역할·갱신 시점 |
|---|---|---|
| `BITWIDTH` | parameter / 기본 16 | 입력·출력 데이터 한 개의 비트 수. 기본 signed INT16 범위를 사용한다. |
| `BITWIDTH_GAP_ITERATION` | parameter / 기본 16 | GAP 입력 개수 N을 전달하는 iteration 포트의 폭. |
| `MAX_GAP_ITERATION` | parameter / 기본 1024 | 지원하는 GAP 최대 N. 양의 2의 거듭제곱이며 반복 횟수 포트로 표현 가능해야 한다. |

### 입출력 포트

| 선언 이름 | 선언 종류·기본 폭/값 | 역할·갱신 시점 |
|---|---|---|
| `clk` | input / 1비트 | 데이터를 수신하고 순차 상태를 갱신하는 상승 에지 클럭. |
| `nrst` | input / 1비트 | 0이면 비동기 reset. 유효 표시와 해당 모듈의 상태를 초기화해 진행 중인 계산을 취소한다. |
| `enable` | input / 1비트 | 블록 기능 선택. 1은 연산, 0은 입력을 같은 단계 수로 우회. 입력 유효 표시와는 다르다. |
| `in_enable` | input / 1비트 | 현재 상승 에지에 in_data가 유효하다는 표시. 0인 클럭은 새 입력으로 세지 않는다. |
| `iteration` | input / 16비트 unsigned | 평균할 유효 입력 수 N. 기본 지원은 1,2,4,…,1024이며 비지원 N은 입력을 폐기한다. |
| `in_data` | input / 16비트 signed | 처리할 입력 한 개. 기본 Q5.10 저장 정수이며, 유효할 때만 연산에 사용한다. |
| `out_enable` | output / 1비트 | 현재 출력 데이터가 유효하다는 표시. 연속 결과이면 여러 클럭 연속 1일 수 있다. |
| `out_data` | output / 16비트 signed 레지스터 | 입력과 같은 Q scale의 반올림 평균. 마지막 입력 E0 → E3 직후 출력. |

### 내부 폭·상수

| 선언 이름 | 선언 종류·기본 폭/값 | 역할·갱신 시점 |
|---|---|---|
| `WORD_W` | localparam / 값 16 | 입출력 데이터 폭 BITWIDTH의 내부 이름. |
| `ITER_W` | localparam / 값 16 | iteration 포트 폭 BITWIDTH_GAP_ITERATION의 내부 이름. |
| `MAX_LOG` | localparam / 값 10 | log2(MAX_GAP_ITERATION). 최대 1024개 합에 필요한 추가 비트 수. |
| `COUNT_W` | localparam / 값 10 | 그룹 카운터 폭. MAX_LOG가 0인 최대 N=1에서도 최소 1비트로 유지한다. |
| `SHIFT_W` | localparam / 값 4 | 0..MAX_LOG의 shift 양을 저장하는 폭. 기본 log2(N)=0..10을 담는다. |
| `SUM_W` | localparam / 값 26 | WORD_W+MAX_LOG. 최대 N개의 signed 합을 보존하는 폭. |
| `MAG_W` | localparam / 값 27 | SUM_W+1. 절댓값과 반올림 덧셈의 여유 폭. |
| `ONE` | localparam / unsigned 27비트, 값 1 | 반올림 보정 half를 만들 때 계산 폭을 고정하는 기준값. |
| `ITER_ONE` | localparam / unsigned 16비트, 값 1 | N의 one-hot 패턴과 MAX_ITER를 만드는 1. iteration 포트 폭에 맞춘다. |
| `MAX_ITER` | localparam / unsigned 16비트, 값 1024 | iteration 포트 폭으로 표현한 지원 최대값. supported의 범위 검사에 사용한다. |

### 내부 데이터·상태·연결 신호

| 선언 이름 | 선언 종류·기본 폭/값 | 역할·갱신 시점 |
|---|---|---|
| `supported` | wire / 1비트 | N>0, N<=MAX_ITER, 2의 거듭제곱 조건을 모두 만족하면 1. 0이면 활성 입력을 폐기한다. |
| `input_shift` | reg 선언 / 조합 4비트 | always @*에서 계산한 log2(N). reg 선언이지만 클럭 저장 레지스터가 아니다. |
| `bit_index` | integer / 조합 for 인덱스 | N=1<<bit_index인지 찾는 인코딩 루프의 인덱스. 입력 횟수를 세는 하드웨어 카운터가 아니다. |
| `input_count` | reg / unsigned 10비트 | 현재 그룹에서 먼저 받은 유효 입력 수. 마지막 입력·우회·비지원/0 입력에서 0이 된다. |
| `accumulator` | reg / signed 26비트, Q10 | 부분합 저장. 다음 그룹 첫 항은 이전 값과 무관하게 in_data로 새 합을 시작하므로 완료 후 값이 남아도 정상이다. |
| `s0_sum` | reg / signed 26비트, Q10 | S0에서 마지막 항까지 모은 합 또는 우회 입력을 저장한다. |
| `s0_shift` | reg / unsigned 4비트 | s0_sum과 같은 그룹의 log2(N). 우회에서는 0을 저장한다. |
| `s1_shift` | reg / unsigned 4비트 | S1의 magnitude와 같은 그룹의 shift 양. |
| `s1_magnitude` | reg / unsigned 27비트, Q10 | S1에 등록한 최종 합의 절댓값. |
| `s2_rounded` | reg / unsigned 16비트, Q10 | S2에 등록한 평균 크기. 32768도 가능하므로 Signed Decimal로 보면 의미를 잘못 읽을 수 있다. |
| `s0_valid` | reg / 1비트 | S0의 최종 합/우회 값이 유효함을 표시. 모든 입력 항마다 1이 되는 것은 아니다. |
| `s1_valid` | reg / 1비트 | S1의 magnitude·부호·shift가 유효하다는 표시. |
| `s2_valid` | reg / 1비트 | S2 결과 valid. 다음 에지 S3에서 out_enable로 전달한다. |
| `s1_negative` | reg / 1비트 | s1_magnitude에 대응하는 원래 합의 음수 여부. |
| `s2_negative` | reg / 1비트 | S2 평균에 복원할 원래 부호. |
| `input_ext` | wire / signed 26비트 | in_data를 합산 폭으로 부호 확장한 값. 평균의 Q scale은 바꾸지 않는다. |
| `total` | wire / signed 26비트, Q10 | accumulator+input_ext의 조합 합. 첫 항은 이 값 대신 input_ext를 직접 사용한다. |
| `last_input` | wire / 1비트 | 활성·유효·지원 N이며 input_count=N-1일 때 1. 최종 합을 보관할 경계다. |
| `extended_sum` | wire / signed 27비트 | s0_sum을 한 비트 부호 확장한 값. S1에서 음수 최솟값도 안전하게 절댓값으로 바꾼다. |
| `half` | wire / unsigned 27비트 | N/2에 해당하는 반올림 보정값. shift=0(N=1)이면 0, 아니면 1<<(shift-1). |
| `rounded_magnitude` | wire / unsigned 27비트 | (s1_magnitude+half)>>s1_shift. 부호를 복원하기 전 평균의 크기. |

`g_invalid`와 `invalid_configuration`은 지원하지 않는 파라미터를 검출하는 generate 분기/인스턴스 이름이다. 정상 데이터 신호나 추가 연산 단계가 아니다.

## 코드와 파형을 따라 읽는 예

N=4에서 [1024,2048,3072,4096]의 합은 10240, 출력은 2560(실수 2.5)이다. N=2에서 [-1,0]→-1: 정확한 절반은 0에서 먼 방향으로 반올림한다.
N=4는 `input_shift=2`, `half=2`를 사용한다. N=3은 `supported=0`이므로 새 결과를 만들지 않는다. 이미 파이프라인에 있던 이전 결과는 계속 배출될 수 있다.
`input_shift`는 조합 변수이고 `s0_shift`/`s1_shift`가 실제 저장 레지스터다. `bit_index`는 조합 루프 인덱스이므로 입력 횟수 카운터와 구분한다.

세부 실행 명령과 reset/입력 공백/포화 확인 순서는 상단의 파형 가이드를 따른다.
