# 버전별 Vivado 리포트

## 목차

1. [1.0.x·1.1.x 캡처 자료](#1-10x11x-캡처-자료)
2. [Timing 비교](#2-timing-비교)
3. [자원 비교: 단독 top 기준](#3-자원-비교-단독-top-기준)
4. [판정과 비교 범위](#4-판정과-비교-범위)
5. [자료 출처](#5-자료-출처)

현재 버전에서 타이밍·Utilization은 `core_report.html`에 저장합니다. SNR·latency는 별도 시뮬레이션으로 저장합니다. [실행 가이드](../docs/GUIDE.md#3-타이밍utilization-보고서)

## 1. 1.0.x·1.1.x 캡처 자료

사용자가 제공한 `report.zip`의 원본 이미지 24장입니다. 두 버전 모두 **10ns(100MHz) 목표, 배치·배선 후(post_route) 결과**임을 사용자에게 확인했습니다.
모듈 단독 OOC 분석이며 전체 시스템의 보드 동작/외부 I/O 타이밍 판정은 별도입니다.

| 버전 | 원본 이미지와 상세 표 | 파형 확인 가이드 |
|---|---|---|
| 1.0.0 | [v1.0.0 리포트](v1.0.0/README.md) | [v1.0.0 waveform](../docs/ANALYSIS.md) |
| 1.1.0 | [v1.1.0 리포트](v1.1.0/README.md) | [v1.1.0 waveform](../docs/ANALYSIS.md) |
| 1.1.1 | [동등성 검증·새 실측 없음](v1.1.1/README.md) | [1.1.x 공통 waveform](../docs/ANALYSIS.md) |

1.1.1은 1.1.0의 가독성 패치입니다. 아래 두 버전의 실측 수치는 그대로 보존하며 [1.1.1 검증](v1.1.1/README.md)을 별도로 구분합니다. [대상 SoC](../docs/SOC.md)는 모든 버전에서 동일합니다.

## 2. Timing 비교

단위는 ns입니다. MET는 이미지에 표시된 Setup/Hold/Pulse Width 조건을 만족한다는 뜻입니다.

| 분석 top | 1.0.0 WNS | 1.0.0 TNS | 1.1.0 WNS | 1.1.0 TNS | 1.0.0 → 1.1.0 |
|---|---:|---:|---:|---:|---|
| core | -58.757 | -1059.432 | +2.716 | 0.000 | VIOLATED → MET |
| MAC (mac top) | -2.651 | -39.869 | +5.073 | 0.000 | VIOLATED → MET |
| Residual | +8.424 | 0.000 | +8.424 | 0.000 | MET → MET |
| ReLU | +8.575 | 0.000 | +8.575 | 0.000 | MET → MET |
| MaxPool | +4.808 | 0.000 | +4.808 | 0.000 | MET → MET |
| GAP | -59.289 | -944.026 | +4.090 | 0.000 | VIOLATED → MET |

1.0.0은 core·MAC·GAP에서 Setup을 위반했습니다. 1.1.0은 6개 분석 top 모두 표시된 Setup/Hold/Pulse Width 위반 endpoint가 0입니다.
core의 WNS는 **−58.757 → +2.716ns**로 61.473ns 증가했고, Setup 위반 endpoint는 **32 → 0**입니다.

## 3. 자원 비교: 단독 top 기준

FF는 Slice Registers입니다. `—`는 이미지에 열이 보이지 않아 확인할 수 없는 값입니다. BRAM 사용량도 첨부 이미지에서 확인할 수 없습니다.

| 분석 top | LUT 1.0.0 | LUT 1.1.0 | FF 1.0.0 | FF 1.1.0 | DSP 1.0.0 | DSP 1.1.0 |
|---|---:|---:|---:|---:|---:|---:|
| core | 1129 | 609 | 413 | 544 | 1 | 1 |
| MAC (mac top) | 211 | 174 | 100 | 186 | 1 | 1 |
| Residual | 36 | 36 | 34 | 34 | — | — |
| ReLU | 9 | 9 | 34 | 34 | — | — |
| MaxPool | 80 | 80 | 66 | 66 | — | — |
| GAP | 735 | 239 | 131 | 135 | — | — |

- core: LUT **1129 → 609(46.1% 감소)**, FF **413 → 544(31.7% 증가)**, DSP **1 → 1**.
- GAP 단독: LUT **735 → 239(67.5% 감소)**. 가변 나눗셈을 지원 크기별 shift로 바꾼 구현과 부합합니다.
- MAC 단독: FF **100 → 186**. 파이프라인을 추가한 구현과 부합합니다.
- Residual·ReLU·MaxPool은 단독 자원과 Timing 수치가 두 버전에서 동일합니다.

단독 `mac` top은 bias=0인 wrapper이고 core 내부 `u_mac`은 bias가 있는 `mac_accumulate`입니다.
또한 통합 최적화/배치 환경이 달라 독립 모듈 수치와 core 내부 계층 수치는 다를 수 있습니다.
계층 자원을 단순 합산하지 말고 전체 사용량은 core 행으로 판단합니다.

## 4. 판정과 비교 범위

1.1.0은 첨부된 OOC post_route 결과에서 100MHz 목표의 표시된 타이밍 조건을 만족했습니다.
가변 나눗셈 제거와 MAC 파이프라인 변경 후의 개선을 보여 주지만, GAP 지원 크기는 기본 1,2,4,…,1024로 제한되고 core 전체 우회는 E0→E14로 늘었습니다.
지연/지원 범위까지 같아진 것은 아니므로 [버전별 waveform 차이](../docs/ANALYSIS.md)를 함께 확인하십시오.

이 결과만으로 최대 동작 주파수, 전체 시스템 타이밍 충족, FPS 또는 CIFAR-10 정확도를 계산하지 않습니다.
기본 실행기의 XDC는 `create_clock`이며, 외부 입출력·reset 제약은 시스템 구성에서 완성해야 합니다.

## 5. 자료 출처

- 원본: 사용자 업로드 `report.zip`, 버전별 TR/UT PNG 총 24장. 이미지는 수정하지 않았습니다.
- 버전 분류: 원본 폴더/파일명. 목표 주기와 post_route 단계: 사용자 확인.
- 프로젝트의 기본 FPGA 설정: xc7z020clg484-1. 이미지에는 전체 part 문자열·Vivado 버전·실행 소스 SHA가 표시되지 않습니다.
- 원본 `.rpt`·XDC·DCP는 첨부되지 않았습니다. 원본 critical path, unconstrained path, DRC/route 상태의 세부 검사는 이 자료로 재현할 수 없습니다.
- [measurements.json](measurements.json): 전사한 수치, 자료 범위, 원본 ZIP/이미지 SHA-256. null은 미표시/미확인 값입니다.

다음 측정에서는 실행 폴더의 원본 `.rpt`, `clock.xdc`, `run_info.tcldict`, `sources/`도 함께 보관하면 실행 조건과 실제 RTL을 대조할 수 있습니다.
