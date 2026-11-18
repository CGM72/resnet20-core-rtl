# 실제 검증 기록

2026-11-18, 새 첨부 `resnet20-accelerator-main.zip` 기반 구현.
검사 대상은 `rtl/compute`이며 이전 SIMD 구현이나 첨부 reference_rtl을 실행하지 않았습니다.

| 검사 | 도구 | 결과 |
|---|---|---|
| 하위 6개 인스턴스, 16-bit/FRAC10 | Icarus Verilog 12.0 | 139,463클럭, 매 클럭 valid/값 일치 |
| 하위 모듈 8-bit/FRAC4 | Icarus Verilog 12.0 | 6,870클럭 일치 |
| Core stream | Icarus Verilog 12.0 | 48개 결과, skip 지연 1/4/7/10/13, Pool/GAP 조합, reset/0반복 복구 통과 |
| 전체 ResNet-20, input_gap=0 | Verilator 5.032 | 22개 affine 레이어의 정수 196,682개 일치 |
| 전체 ResNet-20, input_gap=2 | Verilator 5.032 | 같은 모든 레이어 결과 일치 |
| 로짓 SNR | 독립 Python float 모델 대비 | 54.12dB, 기준 50dB 통과 |
| 가중치 소비 | 첨부 weight.bin | 543,380바이트 일치 |
| 일반 합성/구조 | Yosys 0.52 | check -assert 0건 |
| XC7 DSP 매핑 단계 | Yosys 0.52 | DSP48E1 1개 관찰 |
| Tcl/Bash/Python | parser / bash -n / py_compile | 목록·절대경로·옵션 구성 및 구문 확인 |

Q5.10 최종 로짓:

```text
-4206 -1441 1780 6336 -1278 -612 -2693 326 565 1232
```

직접 Vivado XSim, Vivado 합성/배치배선, post-synthesis XSim, 실제 보드 검증은 수행하지 않았습니다.
Tcl 검사는 Vivado API를 대체한 경로/명령 구성 검사이며 Vivado 실행 결과가 아닙니다.
Windows .bat는 경로/소스 선택을 수정했지만 Windows에서 직접 실행하지 않았습니다.
전체 모델 검증은 결정적 패턴 1개 기준으로, CIFAR-10 테스트셋 분류 정확도 평가는 아닙니다.
첨부 네트워크는 BasicBlock ResNet-20이며 Bottleneck 네트워크로 바꾸지 않았습니다.
Controller/top/AXI/DMA는 구현 범위 밖이므로 전체 시스템 검증 완료를 주장하지 않습니다.

로그 파일은 이 폴더에 있으며 자원 검사 범위는 resource_check.txt에 적었습니다.

### Launcher 수정 검증

`current_project -quiet`가 프로젝트 없음 오류를 반환하는 환경을 재현해 수정했습니다.
`tclsh verification/core/test_launcher.tcl`에서 오류/빈 값 두 경우 모두 tb_modules/tb_core_stream/tb_core 실행 경로를 확인했고,
이미 열린 사용자 프로젝트는 생성/시뮬레이션 전에 차단되는지 확인했습니다.
이는 Vivado API를 대체한 Tcl 회귀검사이며 실제 Vivado 실행을 뜻하지 않습니다.

### 파일명·경로 정리

Tcl 인자, Simulation Top, TB 폴더, .sv와 .f의 기본 이름을
`tb_modules` / `tb_core_stream` / `tb_core`로 통일했습니다.
`tb_core_stream`도 같은 이름의 폴더로 이동했습니다.
이름 또는 해당 .sv 파일명을 넣는 경우 모두 같은 top/프로젝트로 연결되는지 Tcl 회귀검사했습니다.
tb_modules/tb_core_stream의 Icarus 검증은 변경된 .f 위치에서 다시 실행했습니다.
RTL 연산 로직은 변경하지 않았으므로 기존 전체 모델 수치 검증 기록은 그대로 유효합니다.

`path_consistency.txt`: 모든 TB 파일 목록과 module 이름, README/Tcl 대상 경로 일치 검사.
전체 모델 TB는 변경된 공통 목록으로 Verilator lint도 통과했습니다. 이 검사 역시 실제 Vivado 실행은 아닙니다.

### Timing / Utilization PNG 도구 검사

`analysis_export_tests.txt`: 테스트용 Vivado 보고서의 setup/hold 열, N/A/분석 경로 없음, 자원 열/누락/BRAM 소수값,
PNG 4개 생성과 메타데이터를 검사한 Python 15개 테스트.
`analysis_launcher_tests.txt`: 실제 RTL 6개 선택, OOC 합성→clock→보고서→배치배선→보고서 순서,
고유 실행 폴더, 실패 시 latest.txt 유지와 열린 프로젝트 보호를 검사한 Tcl 테스트.
Vivado/export API를 대체한 검사이며 실제 FPGA 자원/Timing 측정 기록이 아닙니다.
생성된 테스트 이미지는 실측값과 혼동하지 않도록 build/에만 두고 저장소/ZIP에 포함하지 않습니다.
