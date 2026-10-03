# DM_Helper for Windows 11

Win11 이관 버전입니다. 원본 macOS 코드(`d3key/`)는 그대로 두었습니다.

## 현재 상태

| Phase | 상태 |
|---|---|
| 코어 모델 / 입력 계층 / 엔진 / 서비스 | ✅ 완료, **테스트 106/106 통과** |
| Phase 0 스파이크 (실기 검증) | ⏳ **Windows 11 실기에서 실행 필요** |
| WPF UI | ⏳ 미착수 |
| 패키징 (단일 exe, 관리자 권한) | ⏳ 미착수 |

## 먼저 검증해야 할 것

코어 계층은 전부 작성·테스트를 마쳤지만, **Win32 입력 주입이 실제 디아블로4에 닿는지는
코드 리뷰로 판정할 수 없습니다.** 그래서 검증용 콘솔 앱을 먼저 만들어 두었습니다.

```bash
cd win
dotnet publish src/DM_Helper.Spike -c Release -r win-x64 --self-contained false
```

산출된 `DM_Helper_Spike.exe`를 **관리자 권한 명령 프롬프트**에서 실행하세요. 9개 항목을
차례대로 검사하고 PASS/FAIL을 출력합니다.

1. 관리자 권한 여부 (UIPI 차단 여부의 선행 조건)
2. 모니터 환경 / DPI 인식
3. `sizeof(INPUT)` = 40바이트 검증
4. `SendInput` — F9, 좌클릭, 휠 주입 + 스캔코드 매핑 확인
5. 저수준 훅 설치
6. **5초간 실제 키/마우스 입력 캡처** (이게 안 되면 매크로가 아예 못 돌아갑니다)
7. 디아블로 프로세스 탐지
8. **120ms 타이머 정밀도 실측**
9. 오프너 → 본 루프 전체 실행

### 결과 해석

- **1번 FAIL** → 관리자 권한으로 재실행. 이게 가장 흔한 원인입니다.
- **6번 FAIL** → 훅 자체가 안 걸립니다. 이 경우 이후 UI 작업이 무의미합니다.
- **4·9번은 통과해도 직접 눈으로 확인해야 합니다.** 스파이크는 Win32 호출이 성공했는지만
  봅니다. Raw Input 경유로 실제 게임에 들어가는지는 게임 앞에서 직접 봐야 합니다.

## 구조

```
win/
├── DM_Helper.sln
├── src/
│   ├── DM_Helper.Core/          net8.0 — Windows targeting 불필요
│   │   ├── Interop/             Win32 P/Invoke, SendInput, 저수준 훅, 모니터
│   │   ├── Engine/              정밀 타이머, 입력 전송 스레드, 매크로 상태머신
│   │   ├── Models/              InputKey, KeyConfig(프리셋 7종), OpenerStep, PresetItem
│   │   └── Services/            설정 저장, 다국어(146키×2), 구글시트, 데드존 필터
│   ├── DM_Helper.Spike/         net8.0-windows — 실기 검증 콘솔 앱
│   └── DM_Helper.Wpf/           (예정) UI
└── tests/DM_Helper.Core.Tests/  106개 테스트
```

`DM_Helper.Core`가 `net8.0`인 이유는 의도적입니다. Win32 관련 코드가 전부 P/Invoke라서
어떤 OS에서도 컴파일되고, 도메인 로직과 interop 마샬링을 어느 머신에서든 테스트할 수
있습니다.

## macOS에서 빌드/테스트

```bash
cd win
dotnet test          # 106개 테스트, 약 5초
```

## 알려진 제약

- **ToS**: 게임 입력 자동화는 Blizzard 약관 위반 소지가 있습니다. 원본 macOS 버전과
  동일한 책임이며, 계정 제재 가능성을 감수해야 합니다.
- WPF UI는 **Windows에서만** 빌드됩니다 (macOS/리눅스에서 `dotnet build` 불가).
