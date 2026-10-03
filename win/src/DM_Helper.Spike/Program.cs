using System.Diagnostics;
using System.Runtime.InteropServices;
using DM_Helper.Core.Engine;
using DM_Helper.Core.Interop;
using DM_Helper.Core.Models;

namespace DM_Helper.Spike;

/// <summary>
/// Phase 0 feasibility spike.
///
/// The whole Windows port rests on two questions that cannot be answered from code review:
///
///   1. Does <c>SendInput</c> reach Diablo 4? It reads raw scancodes through Raw Input /
///      DirectInput, and virtual-key-only injection is silently dropped by those paths.
///   2. Does <c>WH_KEYBOARD_LL</c> capture the start hotkey while the game has focus?
///
/// Run this on a real Windows 11 machine with Diablo 4 open, then follow the prompts. Each
/// step prints PASS/FAIL so the result is unambiguous rather than a matter of opinion.
///
/// Build (from the repo's win/ directory):
///     dotnet publish src/DM_Helper.Spike -c Release -r win-x64 --self-contained false
/// Then run DM_Helper_Spike.exe from an elevated prompt.
/// </summary>
internal static class Program
{
    private static int _failures;

    private static async Task<int> Main(string[] args)
    {
        if (!OperatingSystem.IsWindows())
        {
            Console.Error.WriteLine("This spike only runs on Windows.");
            return 2;
        }

        Title("DM_Helper - Windows 11 입력 계층 검증 (Phase 0 Spike)");

        // Per-monitor DPI awareness is required for the deadzone maths and is also what
        // the shipped app sets before anything else.
        Monitors.EnsurePerMonitorDpiAwareness();
        Pass("DPI 인식 모드 설정", "PerMonitorV2 (cursor coords are physical pixels)");

        CheckElevation();
        CheckEnvironment();
        CheckInputStruct();
        CheckSendInput();
        CheckHook();
        await CheckHookCapturesAsync();
        CheckForegoundDetection();
        CheckPrecision();
        CheckFullEngineLoop();

        Summary();
        return _failures == 0 ? 0 : 1;
    }

    // =====================================================================
    // 1. Elevation
    // =====================================================================

    private static void CheckElevation()
    {
        Console.WriteLine();
        Section("1. 권한 (UIPI)");

        var identity = System.Security.Principal.WindowsIdentity.GetCurrent();
        var principal = new System.Security.Principal.WindowsPrincipal(identity);
        var elevated = principal.IsInRole(System.Security.Principal.WindowsBuiltInRole.Administrator);

        Console.WriteLine($"   계정: {identity.Name}");
        Console.WriteLine($"   권한: {(elevated ? "관리자 (Administrator)" : "일반 (Standard)")}");

        if (elevated)
        {
            Pass("관리자 권한", "SendInput will reach an elevated game process");
        }
        else
        {
            Fail("관리자 권한 없음",
                "재실행해야 합니다. Diablo IV.exe가 관리자 권한으로 실행되면 SendInput이 " +
                "조용히 실패합니다. 관리자 권한으로 재실행하세요.");
        }
    }

    // =====================================================================
    // 2. Environment
    // =====================================================================

    private static void CheckEnvironment()
    {
        Console.WriteLine();
        Section("2. 모니터 환경");

        var all = Monitors.All();
        Console.WriteLine($"   모니터 {all.Count}개, OS {Environment.OSVersion}");

        foreach (var m in all)
            Console.WriteLine($"   - {m.Width}x{m.Height} @ ({m.Left},{m.Top})");

        if (all.Count == 0) Fail("모니터 조회 실패", "GetMonitorInfo가 아무것도 반환하지 않았습니다");
        else Pass("모니터 조회", $"{all.Count}개 감지, 데드존 계산 가능");
    }

    // =====================================================================
    // 3. INPUT struct size
    // =====================================================================

    private static void CheckInputStruct()
    {
        Console.WriteLine();
        Section("3. INPUT 구조체 레이아웃");

        var size = NativeMethods.InputSize;
        Console.WriteLine($"   Marshal.SizeOf<INPUT>() = {size}");

        // A wrong cbSize makes SendInput fail with no useful error, so assert it early.
        if (size == 40) Pass("sizeof(INPUT)", "40바이트 (x64) - SendInput 요구 크기와 일치");
        else Fail("sizeof(INPUT) 오류", $"{size}바이트. 40이어야 합니다.");

        var unionSize = InputLayout.UnionSize;
        Console.WriteLine($"   sizeof(InputUnion) = {unionSize}");
        if (unionSize == 32) Pass("sizeof(union)", "32바이트 (MOUSEINPUT이 최대)");
        else Fail("sizeof(union) 오류", $"{unionSize}바이트. 32이어야 합니다.");
    }

    // =====================================================================
    // 4. SendInput
    // =====================================================================

    private static void CheckSendInput()
    {
        Console.WriteLine();
        Section("4. SendInput 주입");

        Console.WriteLine("   F9 키를 1회 주입합니다 (3초 안에 손을 떼지 마세요).");
        var ok = InputPoster.PostKey(InputKey.FromKey(Vk.F9));
        Report(ok, "키 주입", "F9");

        // A mouse click is harmless on a desktop and proves the mouse path too.
        ok = InputPoster.PostLeftClick();
        Report(ok, "마우스 좌클릭", "왼쪽 버튼 1회");

        ok = InputPoster.PostWheel(WheelDirection.Up);
        Report(ok, "마우스 휠", "위로 3노치");

        // Verify the scancode actually differs per key - if MapVirtualKey returned 0 the
        // game would receive the same undefined scancode for every binding.
        var sc1 = InputPoster.ToScanCode(Vk.D1);
        var sc2 = InputPoster.ToScanCode(Vk.D2);
        var scL = InputPoster.ToScanCode(Vk.Left);

        if (sc1 != 0 && sc2 != 0 && sc1 != sc2)
            Pass("스캔코드 매핑", $"D1=0x{sc1:X2} D2=0x{sc2:X2} (서로 다름)");
        else
            Fail("스캔코드 매핑 실패", $"D1=0x{sc1:X2} D2=0x{sc2:X2}");

        if (scL != 0 && VkExtensions.IsExtendedKey(Vk.Left))
            Pass("확장키 플래그", $"Left=0x{scL:X2}, KEYEVENTF_EXTENDEDKEY 설정됨");
        else
            Fail("확장키 처리 실패", "방향키 스캔코드가 0이거나 extended 판정이 없습니다");
    }

    // =====================================================================
    // 5. Hook
    // =====================================================================

    private static void CheckHook()
    {
        Console.WriteLine();
        Section("5. 저수준 훅 설치 (WH_KEYBOARD_LL / WH_MOUSE_LL)");

        using var hook = new InputHookService();
        var started = hook.Start();

        Report(started, "훅 설치", "키보드 + 마우스 저수준 훅");
    }

    // =====================================================================
    // 6. Hook capture (interactive)
    // =====================================================================

    private static async Task CheckHookCapturesAsync()
    {
        Console.WriteLine();
        Section("6. 훅 실제 캡처 확인 (5초 대기)");

        using var hook = new InputHookService();
        if (!hook.Start())
        {
            Fail("훅 캡처 테스트", "훅을 설치하지 못했습니다. 5번 항목을 먼저 확인하세요.");
            return;
        }

        var captured = new List<string>();
        hook.EventReceived += e => captured.Add(
            $"{(e.IsDown ? "down" : "up")}:{e.Key.DisplayString}");

        Console.WriteLine("   아무 키나 마우스나 움직여 보세요 (5초)...");

        var sw = Stopwatch.StartNew();
        while (sw.Elapsed < TimeSpan.FromSeconds(5))
        {
            foreach (var c in hook.Drain())
            {
                if (captured.Count < 40) captured.Add(
                    $"{(c.IsDown ? "down" : "up")}:{c.Key.DisplayString}");
            }
            await Task.Delay(25);
        }

        var distinct = captured.Select(c => c.Split(':')[1]).Distinct().ToArray();

        if (captured.Count == 0)
        {
            Fail("훅 캡처 실패",
                "5초 동안 아무 이벤트도 잡히지 않았습니다. 관리자 권한과 WH_KEYBOARD_LL 설치를 확인하세요.");
            return;
        }

        Console.WriteLine($"   캡처 {captured.Count}건, 서로 다른 입력 {distinct.Length}종:");
        Console.WriteLine("   " + string.Join(", ", distinct.Take(20)));

        Pass("훅 캡처", $"{captured.Count}건 수신");
    }

    // =====================================================================
    // 7. Foreground detection
    // =====================================================================

    private static void CheckForegoundDetection()
    {
        Console.WriteLine();
        Section("7. 게임 프로세스 탐지");

        foreach (var (proc, title) in new[]
                 {
                     ("Diablo IV", "Diablo IV"),
                     ("Diablo 4", "Diablo IV"),
                 })
        {
            var pids = ForegroundWindow.FindProcessIds(proc);
            var windowTitle = ForegroundWindow.FindWindowTitle(proc);

            Console.WriteLine($"   '{proc}' → 프로세스 {pids.Count}개, 창 제목: {windowTitle ?? "(없음)"}");

            if (pids.Count > 0)
            {
                Pass($"'{proc}' 탐지", $"{pids.Count}개 프로세스, 창 '{windowTitle}'");
            }
            else
            {
                Console.WriteLine($"   ℹ 실행 중이 아닌 것으로 보입니다 (게임 실행 후 재확인 권장)");
            }
        }

        Console.WriteLine($"   현재 전면 프로세스 ID: {ForegroundWindow.ForegroundProcessId}");
    }

    // =====================================================================
    // 8. Timer precision
    // =====================================================================

    private static void CheckPrecision()
    {
        Console.WriteLine();
        Section("8. 타이머 정밀도 (120ms 사이클)");

        using var timer = new PreciseTimer("Spike.Timer");
        var sw = Stopwatch.StartNew();
        var latencies = new List<long>();

        timer.Schedule(() => latencies.Add(sw.ElapsedMilliseconds), 0, 120);

        Thread.Sleep(2000);
        timer.CancelAll();

        if (latencies.Count < 5)
        {
            Fail("타이머 동작", $"{latencies.Count}회만 실행됨 (기대 ~16회)");
            return;
        }

        var gaps = new List<long>();
        for (var i = 1; i < latencies.Count; i++) gaps.Add(latencies[i] - latencies[i - 1]);

        var avg = gaps.Average();
        var max = gaps.Max();

        Console.WriteLine($"   실행 {latencies.Count}회, 평균 간격 {avg:F1}ms, 최대 {max}ms");

        if (max <= 130)
            Pass("타이머 정밀도", $"120ms 목표 대비 최대 {max}ms (지터 {max - 120}ms)");
        else
            Fail("타이머 정밀도", $"최대 간격 {max}ms. 130ms를 넘으면 인게임 스킬이 밀립니다.");
    }

    // =====================================================================
    // 9. Full engine loop
    // =====================================================================

    private static void CheckFullEngineLoop()
    {
        Console.WriteLine();
        Section("9. 엔진 전체 루프 (오프너 → 본 루프)");

        var config = KeyConfig.DefaultConfig();
        config.StartInputKey = InputKey.FromKey(Vk.F9);
        config.StopInputKey = InputKey.FromKey(Vk.F10);

        // Opener: 3 steps, then a 120ms right-click spam, exactly like the Warlock preset.
        config.OpenerEnabled = true;
        config.OpenerSteps[0] = OpenerStep.Create(InputKey.FromKey(Vk.D1), 150, 1, "오프너 1");
        config.OpenerSteps[1] = OpenerStep.Create(InputKey.FromKey(Vk.D2), 150, 1, "오프너 2");
        config.OpenerSteps[2] = OpenerStep.Create(InputKey.FromKey(Vk.D3), 150, 1, "오프너 3");

        config.SkillKeys[4] = InputKey.FromMouse(MouseButton.Right);
        config.SkillDelays[4] = 120;
        config.SkillChecks[4] = true;

        using var engine = new HelperEngine { Config = config };
        var sender = new InputSender();
        sender.Start();

        Console.WriteLine("   오프너 3단계 후 우클릭 120ms 연타를 4초간 실행합니다.");
        Console.WriteLine("   게임을 창 활성화 상태로 두고 실제로 들어가는지 확인하세요.");

        engine.Start();
        Thread.Sleep(4000);
        engine.Stop();
        sender.Dispose();

        var diag = engine.Diagnostics;

        Console.WriteLine($"   스케줄 틱: {diag.SchedulerTicks}, 최대 지터: {diag.MaxLatenessUs / 1000.0:F1}ms");
        Console.WriteLine($"   드롭된 입력: {diag.DroppedInputs}, 마지막 전송 성공: {diag.LastSendSucceeded}");

        if (diag.SchedulerTicks < 20)
            Fail("엔진 루프", $"틱이 {diag.SchedulerTicks}번뿐입니다 (기대 ~35회)");
        else
            Pass("엔진 루프", $"{diag.SchedulerTicks}틱 실행");

        if (diag.MaxLatenessUs > 20_000)
            Fail("스케줄 지터", $"최대 {diag.MaxLatenessUs / 1000.0:F1}ms - 인게임 입력 지연이 체감됩니다");
        else
            Pass("스케줄 지터", $"최대 {diag.MaxLatenessUs / 1000.0:F1}ms");

        if (diag.DroppedInputs > 0)
            Fail("입력 드롭", $"{diag.DroppedInputs}건이 큐 초과로 버려졌습니다");
        else
            Pass("입력 큐", "드롭 없음");

        if (!diag.LastSendSucceeded)
            Fail("입력 전송", diag.LastError ?? "SendInput 실패");
        else
            Pass("입력 전송", "모든 SendInput 성공");
    }

    // =====================================================================
    // Reporting helpers
    // =====================================================================

    private static void Title(string text)
    {
        Console.WriteLine(new string('=', 78));
        Console.WriteLine(text);
        Console.WriteLine(new string('=', 78));
    }

    private static void Section(string text)
    {
        Console.WriteLine();
        Console.WriteLine($"--- {text} " + new string('-', Math.Max(0, 60 - text.Length)));
    }

    private static void Pass(string what, string detail)
    {
        Console.WriteLine($"   [ OK ] {what}: {detail}");
    }

    private static void Fail(string what, string detail)
    {
        _failures++;
        Console.WriteLine($"   [FAIL] {what}: {detail}");
    }

    private static void Report(bool ok, string what, string detail)
    {
        if (ok) Pass(what, detail);
        else Fail(what, $"{detail} 실패 (SendInput이 0을 반환했습니다 - UIPI 차단 가능)");
    }

    private static void Summary()
    {
        Console.WriteLine();
        Console.WriteLine(new string('=', 78));

        if (_failures == 0)
        {
            Console.WriteLine("모든 검증 통과 - Windows 11 이관을 계속 진행할 수 있습니다.");
            Console.WriteLine("다만 실제 디아블로4에서 실제 반응은 눈으로 확인해야 합니다.");
        }
        else
        {
            Console.WriteLine($"{_failures}개 항목 실패 - 위 내용을 확인한 뒤 다시 실행하세요.");
            Console.WriteLine("가장 흔한 원인은 관리자 권한 누락입니다.");
        }

        Console.WriteLine(new string('=', 78));
    }
}
