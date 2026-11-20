# 모듈 선언 사전 — 1.1.1

[실행 가이드](../GUIDE.md) · [파형 가이드](../ANALYSIS.md) · [사용 SoC](../SOC.md)

이 폴더는 **1.1.1의 실제 RTL**에 선언된 파라미터·포트·내부 wire/reg·함수 인자/지역 변수를 설명합니다.
범위는 core와 5개 연산 파일이며, 원본 프레임워크의 Controller/AXI와 테스트벤치 변수는 별도입니다.

처음 읽을 때는 **ReLU → Residual → Pool → MAC → GAP → core** 순서를 권장합니다.
각 문서는 역할 요약 → 데이터 흐름 → 선언별 표 → 숫자 예제 순서입니다.

| 파일 | 설명 | 정리한 선언 수 |
|---|---|---:|
| [core.v](core.md) | core 연결·skip 정렬 | 51 |
| [mac.v](mac.md) | MAC와 bias MAC | 60 |
| [residual.v](residual.md) | Residual 포화 덧셈 | 18 |
| [relu.v](relu.md) | ReLU | 12 |
| [pooling.v](pooling.md) | MaxPool | 15 |
| [general_average_pooling.v](general_average_pooling.md) | Global Average Pooling | 42 |

선언 수는 모듈/함수 범위를 구분해 셉니다. 같은 이름의 함수 인자도 다른 함수에 속하면 별도입니다.
소스에서 추출한 선언 이름과 문서 표를 대조해 누락을 검사했습니다.

## 먼저 알아둘 용어

| 표기 | 쉬운 의미 |
|---|---|
| `input` / `output` | 모듈 바깥과 연결되는 포트 |
| `wire` | 현재 입력/저장값에서 계산되는 연결선. 자체적으로 이전 값을 기억하지 않음 |
| `reg` | Verilog 변수 선언. `posedge`에서 갱신하면 저장 상태, `always @*`에서 계산하면 조합 변수 |
| `parameter` / `localparam` | 외부에서 지정할 수 있는 설정값 / 내부에서 정해지는 상수 |
| `enable` | 연산을 켤지, 입력을 우회시킬지 선택 |
| `in_enable` / `out_enable` | 이번 입력/출력 데이터가 유효한지 표시. 연산 기능 선택과는 다름 |
| `iteration` / `input_count` | 모아야 할 유효 입력 수 N / 앞서 수신한 항 수 |
| `_ext` | 비트 폭을 늘린 값. signed이면 부호를 보존하도록 늘림 |
| `_held` | 상대 데이터가 도착할 때까지 잠시 보관한 값/유효 표시 |
| `_magnitude`, `_negative` | 절댓값 크기 / 원래 음수였는지 표시 |
| `s0`, `s1`, … | 1.1.x 파이프라인의 저장 단계. valid와 해당 데이터가 함께 이동 |
| `pending_*` | 한 단계에서 만든 결과를 다음 출력 단계까지 보관 |

입출력 기본값은 signed INT16/Q5.10이며 **저장 정수 1024가 실수 1.0**입니다.
MAC 곱/누산은 소수 비트가 20인 Q20입니다. 표의 숫자는 기본 파라미터 기준입니다.
문서의 `reg`를 모두 물리 레지스터라고 해석하지 마십시오. core 출력/wrapper 출력과 GAP input_shift는 조합 계산인 예입니다.

## 데이터를 읽는 규칙

1. nrst=1이고 in_enable=1인 상승 에지에만 새 입력으로 계산합니다.
2. out_enable=1인 데이터만 결과로 읽습니다. 연속 결과에서는 out_enable이 연속 1이어도 정상입니다.
3. 설정은 첫 입력 전부터 모든 결과 배출까지 유지합니다. 진행 중 취소는 reset으로 처리합니다.
4. valid=0인 데이터의 X/이전 값은 비교하지 않습니다. 입력 공백 중에도 이전 결과는 뒤에서 배출될 수 있습니다.
5. 함수 안의 reg/변수는 조합 계산용입니다. 함수 호출이 자동으로 여러 클럭을 사용하지는 않습니다.

## 버전 선택

| 버전 | 해당 브랜치의 선언 사전 |
|---|---|
| 1.0.0 | [release/1.0.0](https://github.com/CGM72/resnet20-core-rtl/tree/release/1.0.0/docs/modules) |
| 1.1.0 | [release/1.1.0](https://github.com/CGM72/resnet20-core-rtl/tree/release/1.1.0/docs/modules) |
| 1.1.1 | [release/1.1.1](https://github.com/CGM72/resnet20-core-rtl/tree/release/1.1.1/docs/modules) |

1.0.0은 MAC/GAP의 pending 구조와 함수 지역 변수를, 1.1.0/1.1.1은 MAC/GAP 파이프라인과 skip FIFO를 설명합니다.
1.1.1의 변수/동작은 1.1.0과 같으며 코드 표기와 주석만 정리되었습니다.
