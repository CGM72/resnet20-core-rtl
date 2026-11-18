# RTL 검증·분석 도구

[전체 ZIP 다운로드](https://github.com/CGM72/resnet20-core-rtl/raw/refs/heads/main/downloads/resnet20-core-rtl.zip)

Vivado에서 RTL 기능 검증과 Timing/Utilization PNG 출력을 실행합니다.
ZIP은 새 폴더에 풀어 사용합니다.
기본 예제는 **단일 MAC·INT16·Q5.10 ResNet-20 core**이며, 다른 RTL도 같은 실행기를 사용합니다.

## 빠른 실행

Vivado에서 열린 프로젝트를 저장하고 닫은 뒤 Tcl Console에 입력합니다.
경로는 자신의 폴더로 바꿉니다.

```tcl
source {C:/Users/idec/Desktop/Chae/Project_ResNet/codes/resnet20-core-rtl/scripts/vivado.tcl}
fpga::sim tb_core_stream
```

다음 작업 전에는 `close_sim -force`, `close_project`로 닫습니다.
Timing/자원 분석은 `fpga::analyze`로 실행합니다.
Python은 자동 탐색합니다. PNG에 필요한 Pillow가 없으면 Vivado Tcl에서
`exec {*}[fpga::python_command] -m pip install Pillow`로 설치합니다.

## 바꿀 파일

| 파일 | 역할 |
|---|---|
| project.tcl | RTL 목록·top·클럭·FPGA part 공통 설정 |
| rtl/ | 구현할 모듈 |
| tb/<이름>/<이름>.sv | 기능을 검사할 테스트벤치 |
| tb/<이름>/<이름>.f | TB와 검증용 파일 목록 |
| scripts/vivado.tcl | 공통 실행기. 모듈을 바꿀 때 수정할 필요 없음 |

**같은 포트·기능·수치·타이밍 규약이면 RTL만 교체합니다.** 파일명이나 top이 바뀌면 project.tcl을 수정합니다.
다른 인터페이스/기능의 모듈은 그에 맞는 TB를 추가해야 합니다.

- [사용 가이드: 실행·모듈 교체·결과 확인](docs/GUIDE.md)
- [기본 core의 구조와 연결 규약](docs/architecture.md)

기본 core의 Controller/AXI/DMA는 별도 구현 대상입니다.
제공 TB는 결정적 입력 패턴의 수치 검증이며 CIFAR-10 전체 정확도 평가가 아닙니다.
실제 Vivado 실행 결과는 사용자 PC에서 생성합니다.
