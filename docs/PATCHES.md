# 버전별 패치 내역

버전별 ZIP의 최상위 폴더는 `resnet20-core-rtl/`입니다. 아래 태그는 각 버전의 배포 당시 소스를 가리킵니다. 적용된 문서 개편은 유지보수 브랜치와 ZIP에서 확인할 수 있습니다.

| 버전 | 변경 내역 | 배포 소스 |
| --- | --- | --- |
| 1.2.1 | 전체 모델의 레이어별 RTL 출력 덤프와 Python SNR 추출 추가. 최종 로짓 50 dB 검증 유지. 문서를 다섯 가지 가이드로 개편 | [main](https://github.com/CGM72/resnet20-core-rtl/tree/main) · [ZIP](https://github.com/CGM72/resnet20-core-rtl/raw/refs/heads/main/downloads/resnet20-core-rtl-v1.2.1.zip) |
| 1.1.1 | 1.1.0 RTL의 가독성 개선과 SoC 문서 보강. 기본 core 논리 동등성 확인 | [v1.1.1](https://github.com/CGM72/resnet20-core-rtl/tree/v1.1.1) · [release/1.1.1](https://github.com/CGM72/resnet20-core-rtl/tree/release/1.1.1) · [ZIP](https://github.com/CGM72/resnet20-core-rtl/raw/refs/heads/main/downloads/resnet20-core-rtl-v1.1.1.zip) |
| 1.1.0 | MAC 5단계, GAP 4단계 shift 평균, 4-entry skip FIFO 적용. 기본 GAP 크기는 2의 거듭제곱 | [v1.1.0](https://github.com/CGM72/resnet20-core-rtl/tree/v1.1.0) · [release/1.1.0](https://github.com/CGM72/resnet20-core-rtl/tree/release/1.1.0) · [ZIP](https://github.com/CGM72/resnet20-core-rtl/raw/refs/heads/main/downloads/resnet20-core-rtl-v1.1.0.zip) |
| 1.0.0 | 초기 core와 독립 모듈 테스트벤치, Vivado 분석 흐름. MAC/GAP 2단계와 가변 N 평균 | [v1.0.0](https://github.com/CGM72/resnet20-core-rtl/tree/v1.0.0) · [release/1.0.0](https://github.com/CGM72/resnet20-core-rtl/tree/release/1.0.0) · [ZIP](https://github.com/CGM72/resnet20-core-rtl/raw/refs/heads/main/downloads/resnet20-core-rtl-v1.0.0.zip) |

## 1.2.1 검증

Verilator 전체 모델 테스트에서 22개 레이어의 196,682개 RTL 출력이 정수 기준값과 일치했습니다.
최종 로짓 SNR은 테스트벤치와 Python 모두 54.12 dB였습니다. Vivado Tcl 실행 구성은 모의 API로 검사했습니다. 1.2.1의 Vivado 배치·배선 실측값은 없습니다.

[분석 가이드](ANALYSIS.md) · [1.1.1 동등성 검증 상세](PATCH_1.1.1.md) · [버전별 실측 자료](../reports/README.md)
