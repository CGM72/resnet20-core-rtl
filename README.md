# ResNet-20 Core RTL

## 문서 구성

| 문서 | 내용 |
| --- | --- |
| [실행 가이드](docs/GUIDE.md) | 소스 준비와 Vivado Tcl 명령 |
| [분석 가이드](docs/ANALYSIS.md) | 기능 테스트, 파형, 타이밍, Utilization, SNR 결과 판정 |
| [버전별 패치 내역](docs/PATCHES.md) | 변경 사항 · [최신 배포 ZIP v1.2.6](https://github.com/CGM72/resnet20-core-rtl/raw/refs/heads/main/downloads/resnet20-core-rtl-v1.2.6.zip) · [모든 버전](https://github.com/CGM72/resnet20-core-rtl/releases) |
| [SoC 가이드](docs/SOC.md) | 대상 보드와 PS·PL 통합 범위 |
| [아키텍처](docs/architecture.md) | RTL 구조, 인터페이스, 수치, 지연 |

## 폴더 구성

| 경로 | 내용 |
| --- | --- |
| [docs/](docs/) | 가이드와 모듈별 선언 사전 |
| [rtl/compute/](rtl/compute/) | core와 연산 모듈 RTL |
| [tb/](tb/) | 독립 모듈·core 연결·전체 모델 테스트벤치 |
| [scripts/](scripts/) | Vivado Tcl 실행기 |
| [fpga/](fpga/) | FPGA 지원 파일 |
| [verification/](verification/) | 기준 모델, 가중치, 검증 도구 |
| [reports/](reports/) | 버전별 측정 자료와 비교표 |
| [project.tcl](project.tcl) | FPGA part, 클럭, RTL 소스, 분석 대상 설정 |
| [VERSION](VERSION) | 체크아웃한 소스 버전 |
