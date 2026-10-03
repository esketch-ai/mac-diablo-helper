# DM_Helper for Windows 11

Win11 이관 버전입니다. 원본 macOS 코드(`d3key/`)는 그대로 두었습니다.

## 현재 상태

| Phase | 상태 |
|---|---|
| 코어 모델 / 입력 계층 / 엔진 / 서비스 | ✅ 완료, **테스트 162/162 통과** |
| Phase 0 스파이크 (실기 검증) | ⏳ **Windows 11 실기에서 실행 필요** |
| WPF UI (3탭 + 트레이 + 프리셋 허브 + 가이드) | ✅ 완료 (Win11에서 렌더링 확인 필요) |
| 패키징 (단일 exe, 관리자 권한) | ✅ 완료 — 64MB self-contained exe |
| CI (테스트 3개 OS, 빌드 자동화) | ✅ 5개 잡 전부 통과 |
| 배포 | ✅ [v1.6.0-beta.1](https://github.com/esketch-ai/mac-diablo-helper/releases/tag/v1.6.0-beta.1) 프리릴리즈 |

> **스파이크가 통과해야 정식 릴리즈로 승격합니다.** 입력 주입이 차단되면 앱은 정상
> 실행되지만 매크로가 조용히 아무 일도 하지 않기 때문에, 빌드 성공만으로는 판단할 수
> 없습니다. 릴리즈 절차는 [RELEASING.md](../RELEASING.md)에 있습니다.

### 내려받아 바로 실행

설치 프로그램이 없습니다. 압축을 풀면 exe 하나입니다.

1. `DM_Helper_Spike.exe` 우클릭 → **관리자 권한으로 실행** → 9개 항목 결과 확인
2. `DM_Helper.exe` 우클릭 → **관리자 권한으로 실행**

스파이크는 [.NET 8 런타임](https://dotnet.microsoft.com/download/dotnet/8.0)이
필요합니다. 앱은 self-contained라 설치가 필요 없습니다.

코드 규모: C# 8,044줄 + XAML 1,043줄 (ObjC 8,124줄 대비 약간 작지만, Win32 마샬링이
대신 들어갔고 회귀 테스트 106개가 추가됨).

## 빌드

```bash
# 단일 exe (배포용)
dotnet publish src/DM_Helper.Wpf -c Release -r win-x64

# 스파이크 (실기 검증용, .NET 런타임 필요)
dotnet publish src/DM_Helper.Spike -c Release -r win-x64 --self-contained false
```

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
├── build-assets.py              macOS 아이콘 PNG → Windows .ico 생성
├── src/
│   ├── DM_Helper.Core/          net8.0 — Windows targeting 불필요
│   │   ├── Interop/             Win32 P/Invoke, SendInput, 저수준 훅, 모니터
│   │   ├── Engine/              정밀 타이머, 입력 전송 스레드, 매크로 상태머신
│   │   ├── Models/              InputKey, KeyConfig(프리셋 7종), OpenerStep, PresetItem
│   │   └── Services/            설정 저장, 다국어(146키×2), 구글시트, 데드존 필터
│   ├── DM_Helper.Spike/         net8.0-windows — 실기 검증 콘솔 앱
│   └── DM_Helper.Wpf/           net8.0-windows — UI
│       ├── app.manifest         관리자 권한 + PerMonitorV2
│       ├── Assets/              .ico (build-assets.py 생성물)
│       ├── Controls/            KeyCaptureBox, SkillRowControl
│       ├── Services/            TrayIconController, AppServices
│       ├── Themes/              Light.xaml, Dark.xaml (자동 전환)
│       └── Views/               MainWindow, HelpWindow, PresetShareWindow
└── tests/DM_Helper.Core.Tests/  106개 테스트
```

`DM_Helper.Core`가 `net8.0`인 이유는 의도적입니다. Win32 관련 코드가 전부 P/Invoke라서
어떤 OS에서도 컴파일되고, 도메인 로직과 interop 마샬링을 어느 머신에서든 테스트할 수
있습니다.

## macOS / Windows 주요 API 대응

| macOS | Windows |
|---|---|
| `CGEventPost(kCGHIDEventTap)` | `SendInput` (Vk + ScanCode 동시 지정) |
| `CGEventPostToPid` | 해당 없음 — SendInput이 전역이라 오히려 단순 |
| `CGEventTapCreate(kCGHIDEventTap)` | `WH_KEYBOARD_LL` / `WH_MOUSE_LL` |
| Accessibility(TCC) 권한 | `requireAdministrator` (UIPI 차단 회피) |
| 합성 이벤트 태그 (`kCGEventSourceUserData`) | `LLKHF_INJECTED` 플래그 |
| `NSWorkspace.frontmostApplication` | `GetForegroundWindow` |
| `kVK_ANSI_*` | `VK_*` + `MapVirtualKey(MAPVK_VSC_TO_VK_EX)` |
| `CGDisplayBounds` | `MonitorFromPoint` + `GetMonitorInfo` |
| `NSStatusBar` | `NotifyIcon` (WinForms) |
| `NSAttributedString(HTML)` 가이드 | 네이티브 WPF `TextBlock` |
| `NSUserDefaults` | `%APPDATA%\DM_Helper\profiles\*.json` |
| `dispatch_source` 타이머 | 마감시각 큐 + 전담 스레드 (`PreciseTimer`) |

**관리자 권한이 필수인 이유**: `SendInput`은 UIPI의 적용을 받습니다. 디아블로4가 헬퍼보다
높은 무결성 수준으로 실행되면 모든 합성 입력이 조용히 버려집니다. 권한을 낮게 유지하면서
이 문제를 피할 방법은 없습니다 — 저수준 훅은 자신과 같거나 낮은 수준의 프로세스만 볼 수
있습니다.

## macOS에서 빌드/테스트

```bash
cd win
dotnet test          # 106개 테스트, 약 5초
```

## 알려진 제약

- **ToS**: 게임 입력 자동화는 Blizzard 약관 위반 소지가 있습니다. 원본 macOS 버전과
  동일한 책임이며, 계정 제재 가능성을 감수해야 합니다.
- WPF UI는 **Windows에서만 실행**됩니다. macOS에서 `dotnet build`는 컴파일만 검증하며
  XAML 렌더링은 확인하지 않습니다.
- **UI 실기 검증 미완료**: XAML은 컴파일러가 문법만 검사합니다. 레이아웃이 실제로
  올바르게 그려지는지는 Win11에서 실행해 봐야 합니다. 특히 900px 폭에서 3탭 스크롤과
  홀드 모드에서 ms 입력창 숨김 동작을 눈으로 확인하세요.
