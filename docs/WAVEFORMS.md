# 버전별 Waveform 확인

[사용 SoC와 통합 전제](SOC.md) · [1.1.1 가독성 패치 검증](PATCH_1.1.1.md)

**1.1.1은 1.1.0과 신호명·지연·동작이 동일하므로 아래 1.1.0 열과 공통 가이드를 사용합니다.**

파형은 `valid → 데이터 → 카운터/연산값` 순서로 확인합니다. 실행 중인 소스의 VERSION 또는 Git 브랜치를 먼저 확인하십시오.

| 항목 | 1.0.0 | 1.1.0 |
|---|---|---|
| 모듈별 신호·정상 동작·이유 | [1.0.0 가이드](waveforms/v1.0.0.md) | [1.1.0 가이드](waveforms/v1.1.0.md) |
| MAC | 2단계, pending_enable/data | 5단계, s0/s1/s2/s3/out |
| GAP | 양수 N, 가변 나눗셈, 2단계 | 기본 N=1,2,4,…,1024, shift, 4단계 |
| core skip 정렬 | main/skip 각각 1개 보관 | skip FIFO 4개 + main 1개 보관 |
| 전체 우회 | E0 수신 → E9 출력 → E10 소비 | E0 수신 → E14 출력 → E15 소비 |
| 실측 결과 | [1.0.0 리포트](../reports/v1.0.0/README.md) | [1.1.0 리포트](../reports/v1.1.0/README.md) |

E0은 수신 상승 에지, 출력은 해당 에지의 레지스터 갱신 직후 기준입니다.
Residual·ReLU·MaxPool은 두 버전 모두 2단계입니다.
각 가이드에는 실제 TB 계층 경로, add_wave 명령, 반올림/포화/입력 공백/reset 확인 예를 포함합니다.

```tcl
fpga::finish
fpga::test core
add_wave -r /tb_core_stream/dut/*
```

독립 모듈의 실행 명령과 실제 TB 내부 경로는 각 버전 가이드의 표에 있습니다.
behavioral waveform은 기능/정렬을 검사하고, [Timing/Utilization 리포트](../reports/README.md)는 배치·배선 후 결과를 확인합니다.
