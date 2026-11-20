# 버전별 패치 내역

배포 ZIP의 파일명과 압축 해제 후 최상위 폴더에 버전이 표시됩니다. 예를 들어 `resnet20-core-rtl-v1.2.2.zip`을 풀면 `resnet20-core-rtl-v1.2.2/`가 생성됩니다. 아래 태그는 각 버전의 배포 당시 소스를 가리킵니다. 적용된 문서 개편은 유지보수 브랜치와 ZIP에서 확인할 수 있습니다.

| 버전 | 변경 내역 | 배포 소스 |
| --- | --- | --- |
| 1.2.2 | 합성곱 탭 처리와 skip 정렬을 `rtl/compute/conv.v`로 분리 | [v1.2.2](https://github.com/CGM72/resnet20-core-rtl/tree/v1.2.2) · [ZIP](https://github.com/CGM72/resnet20-core-rtl/raw/refs/heads/main/downloads/resnet20-core-rtl-v1.2.2.zip) |
| 1.2.1 | 전체 모델의 레이어별 RTL 출력 덤프와 Python SNR 추출 추가. 최종 로짓 50 dB 검증 유지. 문서를 다섯 가지 가이드로 개편 | [배포 커밋](https://github.com/CGM72/resnet20-core-rtl/tree/7286fe3115014e6139d166cadbc6cb26c35af6fe) · [ZIP](https://github.com/CGM72/resnet20-core-rtl/raw/refs/heads/main/downloads/resnet20-core-rtl-v1.2.1.zip) |
| 1.1.1 | 1.1.0 RTL의 가독성 개선과 SoC 문서 보강. 기본 core 논리 동등성 확인 | [v1.1.1](https://github.com/CGM72/resnet20-core-rtl/tree/v1.1.1) · [release/1.1.1](https://github.com/CGM72/resnet20-core-rtl/tree/release/1.1.1) · [ZIP](https://github.com/CGM72/resnet20-core-rtl/raw/refs/heads/main/downloads/resnet20-core-rtl-v1.1.1.zip) |
| 1.1.0 | MAC 5단계, GAP 4단계 shift 평균, 4-entry skip FIFO 적용. 기본 GAP 크기는 2의 거듭제곱 | [v1.1.0](https://github.com/CGM72/resnet20-core-rtl/tree/v1.1.0) · [release/1.1.0](https://github.com/CGM72/resnet20-core-rtl/tree/release/1.1.0) · [ZIP](https://github.com/CGM72/resnet20-core-rtl/raw/refs/heads/main/downloads/resnet20-core-rtl-v1.1.0.zip) |
| 1.0.0 | 초기 core와 독립 모듈 테스트벤치, Vivado 분석 흐름. MAC/GAP 2단계와 가변 N 평균 | [v1.0.0](https://github.com/CGM72/resnet20-core-rtl/tree/v1.0.0) · [release/1.0.0](https://github.com/CGM72/resnet20-core-rtl/tree/release/1.0.0) · [ZIP](https://github.com/CGM72/resnet20-core-rtl/raw/refs/heads/main/downloads/resnet20-core-rtl-v1.0.0.zip) |

## 1.2.2 검증

- Yosys 0.52에서 기본 파라미터의 1.2.1과 1.2.2 core를 평탄화해 비교했습니다. 계층 이동으로 이름이 바뀐 신호를 대응시킨 뒤 동등성 지점 828개를 모두 증명했습니다.
- Verilator core 연결 테스트는 531개 출력의 값·지연을 확인했습니다. 전체 모델의 22개 레이어 정수 기준값 비교를 통과했고 Python SNR 보고서는 1.2.1과 바이트 단위로 일치했습니다. 최종 로짓 SNR은 54.12 dB입니다.
- Yosys XC7 평탄화 합성에서 FF 543개와 DSP48E1 1개가 동일했고, LUT 프리미티브 수는 686개에서 691개로 바뀌었습니다. Vivado 배치·배선 후 타이밍과 자원 수치는 미측정입니다.

## 1.2.1 검증

Verilator 전체 모델 테스트에서 22개 레이어의 196,682개 RTL 출력이 정수 기준값과 일치했습니다.
최종 로짓 SNR은 테스트벤치와 Python 모두 54.12 dB였습니다. Vivado Tcl 실행 구성은 모의 API로 검사했습니다. 1.2.1의 Vivado 배치·배선 실측값은 없습니다.

[분석 가이드](ANALYSIS.md) · [1.1.1 동등성 검증 상세](PATCH_1.1.1.md) · [버전별 실측 자료](../reports/README.md)
