# core.v 선언 사전 — 1.1.1

[모듈 목록·읽는 법](README.md) · [실제 RTL](../../rtl/compute/core.v) · [파형 확인](../ANALYSIS.md)

외부에서 순서와 주소를 맞춰 보낸 연산 항을 MAC→Residual→ReLU→MaxPool→GAP로 연결한다. 레이어 실행 순서나 메모리 주소를 만드는 Controller는 이 모듈 밖에 있다.

```text
MAC(5) → main/skip 정렬 → Residual(2) → ReLU(2) → Pool(2) → GAP(4)
```

표의 비트 수·상수 값은 기본 파라미터 기준입니다. `parameter`는 외부 설정, `localparam`은 내부에서 정해지는 상수입니다.
E0은 입력 수신 상승 에지이며, 출력 시점은 해당 에지의 레지스터 갱신 직후입니다.

## 모듈 `core`

### 설정 파라미터

| 선언 이름 | 선언 종류·기본 폭/값 | 역할·갱신 시점 |
|---|---|---|
| `BITWIDTH` | parameter / 기본 16 | 입력·출력 데이터 한 개의 비트 수. 기본 signed INT16 범위를 사용한다. |
| `BITWIDTH_MAC_ITERATION` | parameter / 기본 16 | MAC 반복 횟수 포트와 카운터의 폭. 기본 양수 반복 횟수는 1..65535이다. |
| `BITWIDTH_POOLING_ITERATION` | parameter / 기본 16 | MaxPool 창에 모을 데이터 개수와 카운터의 폭. |
| `BITWIDTH_GAP_ITERATION` | parameter / 기본 16 | GAP 입력 개수 N을 전달하는 iteration 포트의 폭. |
| `PARALLEL_PC` | parameter / 기본 1 | 단일 lane 인터페이스에서 허용되는 값은 1. 숫자만 바꿔 MAC 수가 늘어나지 않는다. |
| `PARALLEL_PF` | parameter / 기본 1 | 현재 지원값은 1. 1이 아니면 core의 잘못된 설정 검사에서 실패한다. |
| `FRAC_W` | parameter / 기본 10 | 고정소수점의 소수 비트 수. 입력값 1024가 실수 1.0에 해당한다. |
| `MAX_GAP_ITERATION` | parameter / 기본 1024 | 지원하는 GAP 최대 N. 양의 2의 거듭제곱이며 반복 횟수 포트로 표현 가능해야 한다. |

### 입출력 포트

| 선언 이름 | 선언 종류·기본 폭/값 | 역할·갱신 시점 |
|---|---|---|
| `clk` | input / 1비트 | 데이터를 수신하고 순차 상태를 갱신하는 상승 에지 클럭. |
| `nrst` | input / 1비트 | 0이면 비동기 reset. 유효 표시와 해당 모듈의 상태를 초기화해 진행 중인 계산을 취소한다. |
| `mac_enable` | input / 1비트 | MAC 기능 선택. 0이면 입력 데이터가 MAC을 우회하며 Residual도 함께 우회한다. |
| `mac_iteration` | input / 16비트 unsigned | 출력 하나를 만들 MAC 항 수. skip 항은 이 횟수에 넣지 않는다. |
| `residual_enable` | input / 1비트 | MAC 결과에 skip을 더할지 선택. 실제 적용 조건은 mac_enable과 함께 1인 경우다. |
| `relu_enable` | input / 1비트 | ReLU 음수 제거 기능 선택. |
| `pooling_enable` | input / 1비트 | 연속한 유효 결과를 모아 최대값으로 줄일지 선택. |
| `pooling_iteration` | input / 16비트 unsigned | MaxPool 창당 모을 데이터 수. 창/채널/주소 순서는 외부가 결정한다. |
| `gap_enable` | input / 1비트 | 같은 채널의 공간 값들을 평균낼지 선택. |
| `gap_iteration` | input / 16비트 unsigned | GAP 평균의 N. 기본 지원값은 1,2,4,…,1024. |
| `in_enable` | input / 1비트 | 현재 상승 에지에 in_data가 유효하다는 표시. 0인 클럭은 새 입력으로 세지 않는다. |
| `in_data` | input / 16비트 bit-vector | 내용은 signed Q5.10으로 사용한다. 평소에는 MAC feature이며, skip 대기 중의 다음 유효 입력은 skip이다. |
| `kernel_data` | input / 16비트 bit-vector | 내용은 signed Q5.10 가중치. MAC 항과 같은 에지에 공급하고 skip 수신 항에서는 사용하지 않는다. |
| `bias_data` | input / 16비트 bit-vector | 내용은 signed Q5.10 bias. 각 MAC 그룹 첫 항의 값만 실제 합에 사용한다. |
| `out_enable` | output / 1비트, 조합 전달 | gap_valid를 그대로 연결한다. output reg 선언이지만 이 포트 때문에 출력 단계가 추가되지는 않는다. |
| `out_data` | output / 16비트 bit-vector, 조합 전달 | gap_data를 그대로 연결한다. 내용은 signed Q5.10 결과이며 Signed Decimal로 확인한다. |

### 내부 폭·상수

| 선언 이름 | 선언 종류·기본 폭/값 | 역할·갱신 시점 |
|---|---|---|
| `SKIP_DEPTH` | localparam / 값 4 | skip 저장 칸 수. 현재 포인터/카운터 폭도 깊이 4에 맞춰 고정되어 있다. |

### 내부 데이터·상태·연결 신호

| 선언 이름 | 선언 종류·기본 폭/값 | 역할·갱신 시점 |
|---|---|---|
| `mac_last_input` | wire / 1비트 | u_mac.last_input의 연결선. 마지막 MAC 항을 받으면 waiting_for_skip을 세운다. |
| `mac_valid` | wire / 1비트 | 내적의 반올림/포화 결과 또는 MAC 우회 값의 유효 표시. 잔차 활성 시 pair_valid 구성에 사용하고 비활성 시 residual_in_valid로 전달한다. |
| `residual_valid` | wire / 1비트 | 잔차 합 또는 우회 결과의 유효 표시. 다음 블록의 in_enable과 연결한다. |
| `relu_valid` | wire / 1비트 | ReLU 또는 우회 결과의 유효 표시. 다음 블록의 in_enable과 연결한다. |
| `pooling_valid` | wire / 1비트 | MaxPool 창 결과 또는 우회 값의 유효 표시. 다음 블록의 in_enable과 연결한다. |
| `gap_valid` | wire / 1비트 | GAP 평균 또는 우회 결과의 유효 표시. 최종 out_enable로 그대로 연결한다. |
| `mac_data` | wire / signed 16비트 | 내적의 반올림/포화 결과 또는 MAC 우회 값. 같은 이름의 valid가 1일 때만 사용한다. |
| `residual_data` | wire / signed 16비트 | 잔차 합 또는 우회 결과. 같은 이름의 valid가 1일 때만 사용한다. |
| `relu_data` | wire / signed 16비트 | ReLU 또는 우회 결과. 같은 이름의 valid가 1일 때만 사용한다. |
| `pooling_data` | wire / signed 16비트 | MaxPool 창 결과 또는 우회 값. 같은 이름의 valid가 1일 때만 사용한다. |
| `gap_data` | wire / signed 16비트 | GAP 평균 또는 우회 결과. 같은 이름의 valid가 1일 때만 사용한다. |
| `use_residual` | wire / 1비트 | mac_enable && residual_enable. 두 기능이 모두 활성일 때만 main/skip 정렬과 합산을 사용한다. |
| `waiting_for_skip` | reg / 1비트 | 마지막 MAC 항 뒤 skip을 기다린다는 상태. skip을 받으면 0으로 돌아간다. |
| `mac_held_valid` | reg / 1비트 | MAC 결과를 보관 중이라는 표시. skip과 한 쌍을 전달하면 지운다. |
| `mac_held_data` | reg / signed 16비트 | skip이 늦을 때 보관하는 MAC 결과. mac_held_valid=1일 때만 의미가 있다. |
| `skip_valid` | wire / 1비트 | waiting_for_skip && in_enable. 현재 입력을 MAC 항 대신 skip으로 받는 조건. |
| `pair_valid` | wire / 1비트 | MAC 결과와 skip이 둘 다 준비됐다는 조건. 실제 Residual 입력 사용 여부는 use_residual이 선택한다. |
| `residual_in_valid` | wire / 1비트 | u_residual.in_enable로 전달. 잔차 활성은 pair_valid, 비활성은 mac_valid를 선택한다. |
| `residual_main` | wire / signed 16비트 | 보관 MAC 값이 있으면 그 값을, 없으면 현재 mac_data를 Residual main으로 선택한다. |
| `residual_skip` | wire / signed 16비트 | FIFO에 값이 있으면 맨 앞 skip, 없으면 지금 들어오는 in_data를 선택한다. |
| `skip_fifo` | reg 배열 / 4×signed 16비트 | MAC보다 먼저 도착한 skip들을 입력 순서대로 저장한다. BRAM 사용을 강제하는 선언은 아니다. |
| `skip_read` | reg / unsigned 2비트 | 다음에 소비할 FIFO 칸 번호. skip_pop=1인 에지에 1 증가하고 3 다음 0으로 순환한다. |
| `skip_write` | reg / unsigned 2비트 | 새 skip을 기록할 FIFO 칸 번호. skip_push=1인 에지에 증가한다. |
| `skip_count` | reg / unsigned 3비트 | 저장된 skip 개수(0..4). push만 있으면 증가, pop만 있으면 감소, 둘 다 있으면 유지한다. |
| `skip_push` | wire / 1비트 | 이번 skip을 FIFO에 저장할 조건. 빈 FIFO에서 바로 main과 짝지어 소비하면 저장하지 않는다. |
| `skip_pop` | wire / 1비트 | FIFO 맨 앞 skip을 main과 짝지어 소비하는 조건. 읽기 포인터를 이동시킨다. |

### 하위 모듈 인스턴스: 변수와 구분

| 이름 | 연결된 모듈 | 역할 |
|---|---|---|
| `u_mac` | mac_accumulate | 내적/bias/반올림/포화 |
| `u_residual` | residual | 정렬된 main+skip 포화 합 |
| `u_relu` | relu | 음수 제거 |
| `u_pooling` | pooling | 창 최대값 |
| `u_gap` | general_average_pooling | 채널 평균 |

`g_invalid`/`invalid_configuration`은 잘못된 파라미터 설정을 검출하는 generate 분기/인스턴스 이름이다. 정상 동작 데이터 신호가 아니다.

## 코드와 파형을 따라 읽는 예

MAC/Residual을 켜고 나머지는 우회합니다. MAC N=1, 입력 1024, 가중치 1024, bias=0이면 MAC 결과는 1024다. 다음 유효 입력을 skip=512로 주면 main/skip 한 쌍의 합은 1536이다.
먼저 온 skip은 `skip_push`로 저장하고 `skip_pop`에서 소비한다. push/pop이 동시에 1이면 `skip_count`가 유지되는 것이 정상이다. FIFO가 비었고 main/skip이 같이 준비되면 직접 전달하므로 push 없이 소비할 수 있다.
모든 블록 우회는 E0 입력 → E14 출력이다. 출력 포트가 `reg`로 선언되어도 core의 마지막 `always @*`는 연결만 수행하며 레지스터 단계를 추가하지 않는다.
`SKIP_DEPTH`만 수정해 FIFO를 확장하면 안 된다. 포인터/개수 폭과 overflow 검사도 현재 깊이 4에 맞춰져 있다.

세부 실행 명령과 reset/입력 공백/포화 확인 순서는 상단의 파형 가이드를 따른다.
