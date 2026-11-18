# ResNet-20 core와 모듈별 검증

[전체 ZIP](https://github.com/CGM72/resnet20-core-rtl/raw/refs/heads/main/downloads/resnet20-core-rtl.zip) · [순서대로 실행하는 가이드](docs/GUIDE.md)

`core.v`와 MAC·Residual·ReLU·MaxPool·GAP를 구현했습니다.
기본 수치 형식은 signed INT16/Q5.10, 단일 MAC입니다. Controller/AXI/DMA는 별도 영역입니다.

## 1. 실행기 불러오기

ZIP은 새 폴더에 풉니다. Vivado에서 열린 사용자 프로젝트를 저장하고 닫은 뒤 Tcl Console에 입력합니다.

```tcl
source {C:/Users/idec/Desktop/Chae/Project_ResNet/codes/resnet20-core-rtl/scripts/vivado.tcl}
```

## 2. 모듈별 기능 검증 → 보고서 생성

아래는 ReLU 예시입니다. **기능 검증과 .rpt 생성에는 Python이 필요 없습니다.**

```tcl
fpga::test relu
# ALL TESTS PASSED 확인
fpga::finish
fpga::analyze relu
```

| 대상 | 실제 RTL | 독립 TB | 기능 검증 | Timing/Utilization 보고서 |
|---|---|---|---|---|
| core | rtl/compute/core.v | tb_core_stream | fpga::test core | fpga::analyze core |
| MAC | rtl/compute/mac.v | tb_mac | fpga::test mac | fpga::analyze mac |
| Residual | rtl/compute/residual.v | tb_residual | fpga::test residual | fpga::analyze residual |
| ReLU | rtl/compute/relu.v | tb_relu | fpga::test relu | fpga::analyze relu |
| MaxPool | rtl/compute/pooling.v | tb_pooling | fpga::test pooling | fpga::analyze pooling |
| GAP | rtl/compute/general_average_pooling.v | tb_general_average_pooling | fpga::test general_average_pooling | fpga::analyze general_average_pooling |

core 내부에서 bias를 받는 MAC 연산부는 같은 파일의 `mac_accumulate`입니다.
그 연산부만 분석하려면 `fpga::analyze mac_accumulate`를 사용합니다. tb_mac은 두 MAC 경로를 모두 검사합니다.

## 3. 결과 확인

- 기능 검증: `build/sim/<TB>/`의 로그/파형과 Console의 PASS.
- 배치배선 후 Timing: `build/analysis/<top>/<실행폴더>/timing/post_route.rpt`
- 배치배선 후 Utilization: 같은 실행 폴더의 `utilization/post_route.rpt`
- 마지막 완료 폴더: `build/analysis/<top>/latest.txt`

PNG가 필요할 때만 Python/Pillow를 준비하고 `fpga::images relu`를 실행합니다.
다음 모듈을 실행하기 전 `fpga::finish`로 현재 생성 프로젝트를 닫습니다.

[가이드](docs/GUIDE.md)에 준비·검증·분석·저장 위치·PNG 변환·모듈 교체 순서를 적었습니다.
[core 구조와 입력 규약](docs/architecture.md)도 확인하십시오.
실제 Vivado 배치배선 결과로 타이밍을 판정해야 하며, 기능 PASS만으로 100MHz 충족을 주장하지 않습니다.
