# 1.1.1 가독성 패치와 동등성 검증

기준은 1.1.0 RTL입니다. core와 5개 하위 모듈에서 들여쓰기·수식 간격·블록 구획·주석을 정리했습니다.
변경된 코드에서는 5개 연산 블록과 15개 레지스터 단계를 구분하고, MAC/GAP의 수신·누산·반올림·출력 단계를 따라 읽을 수 있습니다.
[사용 SoC와 PS/PL 통합 전제](SOC.md)도 각 버전 README와 실행 가이드에 명시했습니다.

## 버전과 배포 파일

1.1.1 배포 당시 `main`은 1.1.1을 가리켰습니다. 고정 버전은 `v1.0.0`·`v1.1.0`·`v1.1.1` 태그로 보존합니다.
버전별 ZIP은 [README 다운로드 표](../README.md)에서 받을 수 있습니다. ZIP 파일명에는 버전이 포함되며 압축을 풀면 최상위 폴더는 `resnet20-core-rtl/`입니다.
1.1.1은 RTL·TB 파일명과 `fpga::test`·`fpga::analyze` 명령을 유지한 가독성 패치입니다.

## 유지한 동작과 성능 특성

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

## 수행한 검증

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

## 검증 명령

아래 유지보수용 검사는 release/1.1.1 소스에서 실행합니다. 기본 Vivado 실행에는 추가 Python 의존성이 없습니다.

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

## Timing/Utilization 자료 구분

1.1.0의 사용자 제공 OOC post_route 실측값(core WNS +2.716ns, LUT 609, FF 544, DSP 1)은 [원본 리포트](../reports/v1.1.0/README.md)에 보존했습니다.
1.1.1은 동일한 RTL 논리/파이프라인을 유지하는 패치이며 별도의 Vivado 배치·배선은 이 환경에서 재실행하지 않았습니다.
기존 수치를 1.1.1의 새 측정값으로 복제하지 않습니다. 도구 버전·배치 시드·제약에 따른 물리 결과는 실제 실행에서 확인할 수 있습니다.
