# 버전별 패치 내역

버전별 다운로드는 [GitHub Releases](https://github.com/CGM72/resnet20-core-rtl/releases)에서 제공합니다. 각 릴리스의 다운로드 링크를 선택하면 해당 버전의 소스와 정리된 문서를 함께 받을 수 있습니다.

## 배포 기준

- 문서 정리, 사용성 개선, 호환성 수정은 `main`에 커밋으로 모읍니다.
- 새 배포가 필요할 때 검증한 변경을 묶어서 `VERSION`, 태그, ZIP, GitHub Release를 함께 갱신합니다. 즉시 배포가 필요한 수정은 별도로 묶을 수 있습니다.
- 최신 개발 변경은 `main`에서, 배포본은 GitHub Releases에서 확인합니다. 기존 배포 태그는 해당 커밋을 계속 가리킵니다.

## 배포 내역

| 버전 | 변경 내역 | 배포 소스 |
| --- | --- | --- |
| 1.2.9 | 타이밍·Utilization은 HTML 하나로 저장하고 비교용 텍스트와 비교 명령 제거 | [v1.2.9 릴리스](https://github.com/CGM72/resnet20-core-rtl/releases/tag/v1.2.9) · [ZIP](https://github.com/CGM72/resnet20-core-rtl/raw/refs/heads/main/downloads/resnet20-core-rtl-v1.2.9.zip) |
| 1.2.8 | Vivado 화면과 비슷한 레이아웃의 `core_report.html` 추가 | [v1.2.8 릴리스](https://github.com/CGM72/resnet20-core-rtl/releases/tag/v1.2.8) · [ZIP](https://github.com/CGM72/resnet20-core-rtl/raw/refs/heads/main/downloads/resnet20-core-rtl-v1.2.8.zip) |
| 1.2.7 | Setup·Hold·Pulse Width와 핵심 Utilization만 `core_report.txt`에 저장 | [v1.2.7 릴리스](https://github.com/CGM72/resnet20-core-rtl/releases/tag/v1.2.7) · [ZIP](https://github.com/CGM72/resnet20-core-rtl/raw/refs/heads/main/downloads/resnet20-core-rtl-v1.2.7.zip) |
| 1.2.6 | 타이밍·Utilization 텍스트를 `fpga::report`와 `fpga::analyze core`에서 저장. 전체 모델 SNR·latency는 `fpga::report_sim`으로 분리 | [v1.2.6 릴리스](https://github.com/CGM72/resnet20-core-rtl/releases/tag/v1.2.6) · [ZIP](https://github.com/CGM72/resnet20-core-rtl/raw/refs/heads/main/downloads/resnet20-core-rtl-v1.2.6.zip) |
| 1.2.5 | 생성된 텍스트를 버전별로 보존하고 `fpga::compare`로 타이밍·Utilization·SNR·latency 비교 | [v1.2.5 릴리스](https://github.com/CGM72/resnet20-core-rtl/releases/tag/v1.2.5) · [ZIP](https://github.com/CGM72/resnet20-core-rtl/raw/refs/heads/main/downloads/resnet20-core-rtl-v1.2.5.zip) |
| 1.2.4 | `reports/core_report.txt` 통합 출력, 시뮬레이션·구현 결과 재사용, Verilator 실행 지원 | [v1.2.4 릴리스](https://github.com/CGM72/resnet20-core-rtl/releases/tag/v1.2.4) · [ZIP](https://github.com/CGM72/resnet20-core-rtl/raw/refs/heads/main/downloads/resnet20-core-rtl-v1.2.4.zip) |
| 1.2.3 | `fpga::report`로 타이밍·Utilization·SNR·latency 보고서를 한 실행 폴더에 저장. 배포 ZIP에서 Windows Python Install Manager 자동 탐색 지원 | [v1.2.3 릴리스](https://github.com/CGM72/resnet20-core-rtl/releases/tag/v1.2.3) · [ZIP](https://github.com/CGM72/resnet20-core-rtl/raw/refs/heads/main/downloads/resnet20-core-rtl-v1.2.3.zip) |
| 1.2.2 | 합성곱 탭 처리와 skip 정렬을 `rtl/compute/conv.v`로 분리 | [v1.2.2 릴리스](https://github.com/CGM72/resnet20-core-rtl/releases/tag/v1.2.2) · [ZIP](https://github.com/CGM72/resnet20-core-rtl/raw/refs/heads/main/downloads/resnet20-core-rtl-v1.2.2.zip) |
| 1.2.1 | 전체 모델의 레이어별 RTL 출력 덤프와 Python SNR 추출 추가. 최종 로짓 50 dB 검증 유지. 문서를 다섯 가지 가이드로 개편 | [v1.2.1 릴리스](https://github.com/CGM72/resnet20-core-rtl/releases/tag/v1.2.1) · [ZIP](https://github.com/CGM72/resnet20-core-rtl/raw/refs/heads/main/downloads/resnet20-core-rtl-v1.2.1.zip) |
| 1.1.1 | 1.1.0 RTL의 가독성 개선과 SoC 문서 보강. 기본 core 논리 동등성 확인 | [v1.1.1 릴리스](https://github.com/CGM72/resnet20-core-rtl/releases/tag/v1.1.1) · [ZIP](https://github.com/CGM72/resnet20-core-rtl/raw/refs/heads/main/downloads/resnet20-core-rtl-v1.1.1.zip) |
| 1.1.0 | MAC 5단계, GAP 4단계 shift 평균, 4-entry skip FIFO 적용. 기본 GAP 크기는 2의 거듭제곱 | [v1.1.0 릴리스](https://github.com/CGM72/resnet20-core-rtl/releases/tag/v1.1.0) · [ZIP](https://github.com/CGM72/resnet20-core-rtl/raw/refs/heads/main/downloads/resnet20-core-rtl-v1.1.0.zip) |
| 1.0.0 | 초기 core와 독립 모듈 테스트벤치, Vivado 분석 흐름. MAC/GAP 2단계와 가변 N 평균 | [v1.0.0 릴리스](https://github.com/CGM72/resnet20-core-rtl/releases/tag/v1.0.0) · [ZIP](https://github.com/CGM72/resnet20-core-rtl/raw/refs/heads/main/downloads/resnet20-core-rtl-v1.0.0.zip) |

## 1.2.3 검증

Verilator 전체 모델 시뮬레이션에서 22개 레이어와 전체 추론의 latency를 저장했습니다.
기본 테스트 조건에서 전체 추론은 40,899,571클럭이며, SNR 보고서는 1.2.2와 일치했습니다.
Vivado Tcl 보고서 흐름과 경로는 모의 API로 검증했습니다. Vivado 배치·배선 실측은 별도입니다.

## 1.2.2 검증

- Yosys 0.52에서 기본 파라미터의 1.2.1과 1.2.2 core를 평탄화해 비교했습니다. 계층 이동으로 이름이 바뀐 신호를 대응시킨 뒤 동등성 지점 828개를 모두 증명했습니다.
- Verilator core 연결 테스트는 531개 출력의 값·지연을 확인했습니다. 전체 모델의 22개 레이어 정수 기준값 비교를 통과했고 Python SNR 보고서는 1.2.1과 바이트 단위로 일치했습니다. 최종 로짓 SNR은 54.12 dB입니다.
- Yosys XC7 평탄화 합성에서 FF 543개와 DSP48E1 1개가 동일했고, LUT 프리미티브 수는 686개에서 691개로 바뀌었습니다. Vivado 배치·배선 후 타이밍과 자원 수치는 미측정입니다.

## 1.2.1 검증

Verilator 전체 모델 테스트에서 22개 레이어의 196,682개 RTL 출력이 정수 기준값과 일치했습니다.
최종 로짓 SNR은 테스트벤치와 Python 모두 54.12 dB였습니다. Vivado Tcl 실행 구성은 모의 API로 검사했습니다. 1.2.1의 Vivado 배치·배선 실측값은 없습니다.

[분석 가이드](ANALYSIS.md) · [버전별 실측 자료](../reports/README.md)

## 1.1.1 가독성 패치와 동등성 검증

기준은 1.1.0 RTL입니다. core와 5개 하위 모듈에서 들여쓰기·수식 간격·블록 구획·주석을 정리했습니다.
변경된 코드에서는 5개 연산 블록과 15개 레지스터 단계를 구분하고, MAC/GAP의 수신·누산·반올림·출력 단계를 따라 읽을 수 있습니다.
[사용 SoC와 PS/PL 통합 전제](SOC.md)도 각 버전 README와 실행 가이드에 명시했습니다.

### 버전과 배포 파일

1.1.1 배포 당시 `main`은 1.1.1을 가리켰습니다. 고정 버전은 `v1.0.0`·`v1.1.0`·`v1.1.1` 태그로 보존합니다.
버전별 ZIP은 [버전별 다운로드 표](#버전별-패치-내역)에서 받을 수 있습니다. ZIP 파일명에는 버전이 포함되며 압축을 풀면 최상위 폴더는 `resnet20-core-rtl-v1.1.1/`입니다.
1.1.1은 RTL·TB 파일명과 `fpga::test`·`fpga::analyze` 명령을 유지한 가독성 패치입니다.

### 유지한 동작과 성능 특성

| 항목 | 1.1.0 / 1.1.1 공통 |
|---|---|
| 보드 / SoC / part | ZedBoard / Zynq-7000 XC7Z020 / xc7z020clg484-1 |
| 수치 / 병렬도 | signed INT16/Q5.10, 단일 lane |
| MAC / GAP 단계 | 5 / 4 |
| 전체 우회 | E0 수신 → E14 출력 → E15 소비 |
| 처리율 | 한 입력 항/클럭 수신. 실제 결과 빈도는 각 그룹 반복 횟수에 따름 |
| GAP 지원 N | 기본 1,2,4,…,1024 |
| skip 정렬 | 기존 4-entry FIFO와 MAC 결과 보관 |
| 인터페이스 | 포트·파라미터·내부 신호명·reset/valid 규약 유지 |
| 합성 회로 | 논리식·연산 순서·비트폭·레지스터·합성 속성 유지 |

RTL의 주석/공백을 제외한 토큰이 6개 파일 모두 1.1.0과 같습니다.
따라서 산술식이나 DSP 속성을 바꾸는 리팩토링을 포함하지 않습니다. 기존 파형 경로도 그대로 사용합니다.

### 수행한 검증

| 검사 | 결과 |
|---|---|
| Verilog 토큰 비교 | 6개 파일 동일. 문자열·전처리 토큰·다중 연산자·합성 속성 구분자를 포함해 비교 |
| Yosys 0.52 기본 core 논리 동등성 | 828개 equivalence point 증명, 미증명 0 |
| Icarus Verilog 독립 모듈 TB | MAC/bias MAC·Residual·ReLU·Pool·GAP의 값과 valid 비교 PASS |
| core 연결 TB | 531개 출력, 정확한 지연·입력 공백·skip/FIFO·reset·Pool/GAP 조합 PASS |
| Verilator 전체 ResNet-20 | 22개 연산 레이어 정수 기준값 일치, 로짓 SNR 54.12dB, ALL TESTS PASSED |
| Verilog-2005 구문 | core와 하위 모듈 컴파일 PASS |

논리 동등성은 기본 파라미터로 두 core를 각각 처리한 뒤 flatten/memory_map, equiv_struct, async2sync, equiv_simple/equiv_induct, equiv_status -assert로 확인했습니다.
토큰 비교는 파라미터의 수식 자체도 유지되는지를 별도로 확인합니다. asynchronous reset의 중간 취소는 기능 TB에서도 검사합니다.

### 검증 명령

아래 검사는 1.1.1 릴리스 ZIP 또는 v1.1.1 소스에서 실행합니다. 기본 Vivado 실행에는 추가 Python 의존성이 없습니다.

```bash
# Git checkout: v1.1.0 태그와 RTL 토큰 비교
python verification/tools/check_rtl_tokens.py

# 선택 사항: Yosys가 설치되어 있으면 기본 core 논리 동등성도 확인
python verification/tools/check_rtl_tokens.py --yosys yosys

# Git 없는 ZIP: 풀어 놓은 1.1.0 폴더를 기준으로 비교
python verification/tools/check_rtl_tokens.py --reference-dir ../resnet20-core-rtl-v1.1.0
```

Vivado 기능 검증은 기존 방식입니다. scripts/vivado.tcl을 source한 뒤:

```tcl
fpga::test core
fpga::finish
fpga::test mac
```

다른 모듈 실행 전에도 fpga::finish를 사용합니다. 모듈별 전체 명령과 파형은 [가이드](GUIDE.md)와 [공통 1.1.x waveform](ANALYSIS.md)을 따릅니다.

### Timing/Utilization 자료 구분

1.1.0의 사용자 제공 OOC post_route 실측값(core WNS +2.716ns, LUT 609, FF 544, DSP 1)은 [원본 리포트](../reports/v1.1.0/README.md)에 보존했습니다.
1.1.1은 동일한 RTL 논리/파이프라인을 유지하는 패치이며 별도의 Vivado 배치·배선은 이 환경에서 재실행하지 않았습니다.
기존 수치를 1.1.1의 새 측정값으로 복제하지 않습니다. 도구 버전·배치 시드·제약에 따른 물리 결과는 실제 실행에서 확인할 수 있습니다.
