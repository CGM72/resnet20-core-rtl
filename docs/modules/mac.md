# mac.v 선언 사전 — 1.1.1

## 목차

- [모듈 `mac`](#모듈-mac)
  - [설정 파라미터](#설정-파라미터)
  - [입출력 포트](#입출력-포트)
  - [내부 데이터·상태·연결 신호](#내부-데이터상태연결-신호)
- [모듈 `mac_accumulate`](#모듈-mac_accumulate)
  - [설정 파라미터](#설정-파라미터-1)
  - [입출력 포트](#입출력-포트-1)
  - [내부 폭·상수](#내부-폭상수)
  - [내부 데이터·상태·연결 신호](#내부-데이터상태연결-신호-1)
- [코드와 파형을 따라 읽는 예](#코드와-파형을-따라-읽는-예)

[모듈 목록·읽는 법](README.md) · [실제 RTL](../../rtl/compute/mac.v) · [파형 확인](../ANALYSIS.md)

한 그룹의 입력×가중치를 더해 내적을 만든다. Conv/FC의 항 순서와 개수는 외부에서 정한다. 같은 파일에 bias=0 wrapper인 mac과 실제 누산 연산부 mac_accumulate가 있다.

```text
S0 곱/그룹 경계 → S1 누산/최종 합 → S2 절댓값 → S3 반올림 → S4 포화/부호 복원
```

표의 비트 수·상수 값은 기본 파라미터 기준입니다. `parameter`는 외부 설정, `localparam`은 내부에서 정해지는 상수입니다.
E0은 입력 수신 상승 에지이며, 출력 시점은 해당 에지의 레지스터 갱신 직후입니다.

## 모듈 `mac`

이 모듈은 내부 `u_accumulate`의 bias를 0으로 고정한다. 출력은 연결선으로 전달하므로 wrapper가 지연을 더하지 않는다.

### 설정 파라미터

| 선언 이름 | 선언 종류·기본 폭/값 | 역할·갱신 시점 |
|---|---|---|
| `BITWIDTH` | parameter / 기본 16 | 입력·출력 데이터 한 개의 비트 수. 기본 signed INT16 범위를 사용한다. |
| `BITWIDTH_MAC_ITERATION` | parameter / 기본 16 | MAC 반복 횟수 포트와 카운터의 폭. 기본 양수 반복 횟수는 1..65535이다. |
| `FRAC_W` | parameter / 기본 10 | 고정소수점의 소수 비트 수. 입력값 1024가 실수 1.0에 해당한다. |

### 입출력 포트

| 선언 이름 | 선언 종류·기본 폭/값 | 역할·갱신 시점 |
|---|---|---|
| `clk` | input / 1비트 | 데이터를 수신하고 순차 상태를 갱신하는 상승 에지 클럭. |
| `nrst` | input / 1비트 | 0이면 비동기 reset. 유효 표시와 해당 모듈의 상태를 초기화해 진행 중인 계산을 취소한다. |
| `enable` | input / 1비트 | 블록 기능 선택. 1은 연산, 0은 입력을 같은 단계 수로 우회. 입력 유효 표시와는 다르다. |
| `in_enable` | input / 1비트 | 현재 상승 에지에 in_data가 유효하다는 표시. 0인 클럭은 새 입력으로 세지 않는다. |
| `iteration` | input / 16비트 unsigned | 그룹당 유효 입력 수 N. 활성 상태의 0은 입력을 폐기하고 부분 그룹을 초기화한다. |
| `in_data` | input / 16비트 signed | 처리할 입력 한 개. 기본 Q5.10 저장 정수이며, 유효할 때만 연산에 사용한다. |
| `kernel_data` | input / 16비트 signed | in_data와 짝을 이루는 가중치. 두 값의 곱은 소수 비트가 20인 Q20이다. |
| `out_enable` | output / 1비트, 조합 전달 | 내부 result_valid를 그대로 내보낸다. 이 wrapper는 별도 출력 레지스터 단계를 추가하지 않는다. |
| `out_data` | output / 16비트 signed, 조합 전달 | 내부 result_data를 그대로 내보낸다. bias는 wrapper 안에서 0으로 고정한다. |

### 내부 데이터·상태·연결 신호

| 선언 이름 | 선언 종류·기본 폭/값 | 역할·갱신 시점 |
|---|---|---|
| `result_valid` | wire / 1비트 | u_accumulate의 out_enable 연결선. wrapper의 out_enable로 전달한다. |
| `result_data` | wire / signed 16비트 | u_accumulate의 out_data 연결선. wrapper의 out_data로 전달한다. |

## 모듈 `mac_accumulate`

core의 `u_conv.u_mac`이 사용하는 실제 연산부다. `mac` wrapper의 내부에도 같은 모듈이 있다.

### 설정 파라미터

| 선언 이름 | 선언 종류·기본 폭/값 | 역할·갱신 시점 |
|---|---|---|
| `BITWIDTH` | parameter / 기본 16 | 입력·출력 데이터 한 개의 비트 수. 기본 signed INT16 범위를 사용한다. |
| `BITWIDTH_MAC_ITERATION` | parameter / 기본 16 | MAC 반복 횟수 포트와 카운터의 폭. 기본 양수 반복 횟수는 1..65535이다. |
| `FRAC_W` | parameter / 기본 10 | 고정소수점의 소수 비트 수. 입력값 1024가 실수 1.0에 해당한다. |

### 입출력 포트

| 선언 이름 | 선언 종류·기본 폭/값 | 역할·갱신 시점 |
|---|---|---|
| `clk` | input / 1비트 | 데이터를 수신하고 순차 상태를 갱신하는 상승 에지 클럭. |
| `nrst` | input / 1비트 | 0이면 비동기 reset. 유효 표시와 해당 모듈의 상태를 초기화해 진행 중인 계산을 취소한다. |
| `enable` | input / 1비트 | 블록 기능 선택. 1은 연산, 0은 입력을 같은 단계 수로 우회. 입력 유효 표시와는 다르다. |
| `in_enable` | input / 1비트 | 현재 상승 에지에 in_data가 유효하다는 표시. 0인 클럭은 새 입력으로 세지 않는다. |
| `iteration` | input / 16비트 unsigned | 그룹당 유효 입력 수 N. 활성 상태의 0은 입력을 폐기하고 부분 그룹을 초기화한다. |
| `in_data` | input / 16비트 signed | 처리할 입력 한 개. 기본 Q5.10 저장 정수이며, 유효할 때만 연산에 사용한다. |
| `kernel_data` | input / 16비트 signed | in_data와 짝을 이루는 가중치. 두 값의 곱은 소수 비트가 20인 Q20이다. |
| `bias_data` | input / 16비트 signed | 그룹의 첫 항에서만 사용하는 bias. 누산할 때 FRAC_W만큼 왼쪽으로 옮겨 곱의 단위에 맞춘다. |
| `last_input` | output / 1비트 조합 | enable=1, 유효 입력, N>0, input_count=N-1일 때 1. core가 다음 입력을 skip으로 구분하는 경계다. |
| `out_enable` | output / 1비트 레지스터 | s3_valid를 전달한 S4 결과 valid. 마지막 항 E0 기준 E4 직후 유효. |
| `out_data` | output / 16비트 signed 레지스터 | 최종 내적을 Q5.10으로 반올림하고 -32768..32767로 포화한 결과. enable=0이면 입력을 전달한다. |

### 내부 폭·상수

| 선언 이름 | 선언 종류·기본 폭/값 | 역할·갱신 시점 |
|---|---|---|
| `WORD_W` | localparam / 값 16 | 데이터 폭의 내부 이름. BITWIDTH와 같다. |
| `ITER_W` | localparam / 값 16 | 반복 횟수/입력 카운터 폭. BITWIDTH_MAC_ITERATION과 같다. |
| `PROD_W` | localparam / 값 32 | 곱의 폭. WORD_W+WORD_W로 두 입력의 곱을 보존한다. |
| `ACC_W` | localparam / 값 48 | 누산 폭. PROD_W+ITER_W로 반복 누산의 여유 비트를 확보한다. |
| `MAG_W` | localparam / 값 49 | 부호 확장과 절댓값 계산에 사용하는 폭. ACC_W+1로 최솟값의 절댓값도 표현한다. |
| `ONE` | localparam / unsigned 49비트, 값 1 | HALF와 출력 크기 한계를 만들 때 폭이 명확한 1을 제공한다. |
| `HALF` | localparam / 값 512 | FRAC_W=10의 반올림 보정값. 절댓값에 더한 뒤 오른쪽으로 10비트 옮긴다. |
| `POS_LIMIT` | localparam / 값 32767 | 양수 출력 magnitude의 최대값. 초과하면 INT16 최댓값으로 포화한다. |
| `NEG_LIMIT` | localparam / 값 32768 | 음수 출력이 가질 수 있는 magnitude 한계. 부호 복원 후 -32768까지 허용한다. |

### 내부 데이터·상태·연결 신호

| 선언 이름 | 선언 종류·기본 폭/값 | 역할·갱신 시점 |
|---|---|---|
| `input_count` | reg / unsigned 16비트 | 현재 그룹에서 먼저 받은 유효 항 수(0..N-1). 마지막 항·우회·N=0에서 0으로 돌아간다. |
| `s0_valid` | reg / 1비트 | S0에 현재 처리할 항이 있다는 표시. 입력 공백은 0으로 전달한다. |
| `s0_first` | reg / 1비트 | 해당 항이 그룹 첫 항인지 저장. S1에서 이전 합 대신 첫 항 bias를 선택한다. |
| `s0_last` | reg / 1비트 | 해당 항이 그룹 마지막인지 저장. S1에서 최종 합/결과 valid를 생성한다. |
| `s0_bypass` | reg / 1비트 | 해당 입력이 MAC 우회 값인지 저장. 뒤 단계에서 같은 경로 지연을 유지한다. |
| `s0_product` | reg / signed 32비트, Q20 | S0에 등록한 in_data×kernel_data. use_dsp 속성은 DSP 구현을 요청한다. |
| `s0_bias` | reg / signed 16비트, Q10 | 곱과 함께 저장한 bias. S0 첫 항 표시가 1일 때만 S1 합에 사용한다. |
| `s0_data` | reg / signed 16비트, Q10 | 우회용 원래 입력. S1에서 shift해 뒤 반올림/출력 단계와 단위를 맞춘다. |
| `accumulator` | reg / signed 48비트, Q20 | S0 곱이 도착한 다음 에지에 부분합을 갱신한다. 완료 후 값이 남아도 다음 첫 항에서 새 bias+곱으로 시작한다. |
| `s1_sum` | reg / signed 48비트, Q20 | S1에서 완성된 최종 합 또는 변환한 우회 값을 저장한다. |
| `s1_valid` | reg / 1비트 | S1에 결과가 준비됐다는 표시. 각 MAC 항이 아니라 마지막 항/우회 값에 대해서만 1이다. |
| `s2_magnitude` | reg / unsigned 49비트 | S2에서 저장한 최종 합의 절댓값. Q20 단위다. |
| `s3_rounded` | reg / unsigned 49비트, Q10 | S3에서 (magnitude+HALF)>>FRAC_W로 반올림한 크기. 아직 포화/부호 복원 전이다. |
| `s2_negative` | reg / 1비트 | 원래 최종 합이 음수였다는 표시. magnitude와 함께 이동한다. |
| `s3_negative` | reg / 1비트 | S3의 반올림 값에 적용할 원래 부호. |
| `s2_valid` | reg / 1비트 | S2의 절댓값·부호가 유효하다는 표시. |
| `s3_valid` | reg / 1비트 | S3 결과가 유효하다는 표시. 다음 에지 S4에서 out_enable로 전달한다. |
| `accepted` | wire / 1비트 | in_enable이고 우회이거나 N>0이면 1. S0에 유효 입력을 등록하는 조건이다. |
| `product_ext` | wire / signed 48비트 | 32비트 곱의 부호를 유지하며 누산 폭으로 늘린 값. |
| `bias_ext` | wire / signed 48비트 | bias를 누산 폭으로 부호 확장한 값. 왼쪽 shift 후 Q20 단위가 된다. |
| `bypass_ext` | wire / signed 48비트 | s0_data의 부호 확장. FRAC_W shift 후 s1_sum으로 보내 우회도 동일 지연으로 처리한다. |
| `total` | wire / signed 48비트, Q20 | S0의 첫 항이면 shift한 bias+곱, 이후면 accumulator+곱. S1에서 사용한다. |
| `extended_sum` | wire / signed 49비트 | s1_sum의 부호를 한 비트 더 확장. S2 절댓값 계산이 안전하도록 한다. |

`g_invalid`와 `invalid_configuration`은 지원하지 않는 파라미터를 검출하는 generate 분기/인스턴스 이름이다. 정상 데이터 신호나 추가 연산 단계가 아니다.

## 코드와 파형을 따라 읽는 예

bias를 받는 mac_accumulate/core의 예입니다. N=2, 입력과 가중치가 두 항 모두 1024, 첫 항 bias=1024이면 최종 저장 정수는 3072(실수 3.0)다. 두 번째 항의 bias는 합에 추가하지 않는다. bias가 0으로 고정된 mac wrapper에서는 같은 입력의 결과가 2048이다.
마지막 항 E0 기준 E4 직후 출력한다. 입출력은 Q10, 곱/누산은 Q20이므로 파형 숫자를 같은 배율로 읽지 않는다.
`input_count`는 입력 수신 에지에 갱신되고, `accumulator`는 곱을 S0에 등록한 한 클럭 뒤(S1)에 갱신된다. `in_enable=0`인 클럭에도 이전 곱 때문에 누산값이 바뀔 수 있다. 데이터 레지스터의 reset 후 X/이전 값은 valid=0이면 의미가 없다.

세부 실행 명령과 reset/입력 공백/포화 확인 순서는 상단의 파형 가이드를 따른다.
