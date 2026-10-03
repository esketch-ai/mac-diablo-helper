using System.Diagnostics;
using DM_Helper.Core.Engine;
using DM_Helper.Core.Interop;

namespace DM_Helper.Core.Tests;

/// <summary>
/// Verifies the scheduler's cadence and that the Win32 <c>INPUT</c> records are assembled
/// correctly.
///
/// Timing budgets are deliberately loose. A shared CI runner cannot guarantee CPU
/// availability, and a test that fails because the machine was busy is worse than useless -
/// it trains people to ignore red. What is asserted here is structural behaviour: does the
/// scheduler repeat, does it keep pace, does it spread its ticks. The actual jitter
/// measurement belongs to <c>DM_Helper_Spike</c> on the user's own hardware, where a
/// 120ms rotation genuinely matters.
/// </summary>
[Collection(SerialCollection.Name)]
public class PrecisionAndInputRecordTests
{
    /// <summary>
    /// Runs the scheduler for a fixed wall-clock window and returns the tick count. Timing
    /// the window rather than sleeping a fixed amount means a busy runner yields
    /// proportionally fewer ticks instead of failing outright.
    /// </summary>
    private static (int Ticks, long ElapsedMs) RunFor(int periodMs, int runMs)
    {
        using var timer = new PreciseTimer();
        var count = 0;
        var clock = Stopwatch.StartNew();

        timer.Schedule(() => Interlocked.Increment(ref count), 0, periodMs);

        while (clock.ElapsedMilliseconds < runMs) Thread.Sleep(10);

        timer.CancelAll();
        return (count, clock.ElapsedMilliseconds);
    }

    [Fact]
    public void TimerFiresRepeatedlyAtTheRequestedPeriod()
    {
        const int period = 50;
        const int window = 700;

        var (ticks, elapsed) = RunFor(period, window);

        // At least half the theoretical rate: enough to prove it repeats rather than
        // firing once, without demanding a speed from an unknown machine.
        var floor = (elapsed / period) / 2;
        Assert.True(ticks >= floor,
            $"expected at least {floor} ticks in {elapsed}ms at a {period}ms period, saw {ticks}");
    }

    [Fact]
    public void TimerKeepsUpOverALongerWindow()
    {
        const int period = 100;
        const int window = 1200;

        var (ticks, elapsed) = RunFor(period, window);

        var floor = (elapsed / period) / 2;
        Assert.True(ticks >= floor,
            $"expected at least {floor} ticks in {elapsed}ms at a {period}ms period, saw {ticks}");
    }

    /// <summary>
    /// Guards against a scheduler that fires in one burst and then stalls. Ticks must be
    /// spread across the window, not clustered at the start.
    /// </summary>
    [Fact]
    public void TimerPaceIsSpreadRatherThanBursting()
    {
        const int period = 60;
        const int window = 900;

        using var timer = new PreciseTimer();
        var clock = Stopwatch.StartNew();
        var stamps = new List<long>();

        timer.Schedule(() =>
        {
            lock (stamps) stamps.Add(clock.ElapsedMilliseconds);
        }, 0, period);

        while (clock.ElapsedMilliseconds < window) Thread.Sleep(10);
        timer.CancelAll();

        long[] snapshot;
        lock (stamps) snapshot = stamps.ToArray();

        Assert.True(snapshot.Length >= 5, $"only {snapshot.Length} ticks recorded");

        var span = snapshot[^1] - snapshot[0];
        Assert.True(span > 400,
            $"ticks clustered within {span}ms of a {window}ms window - the scheduler is bursting");

        for (var i = 1; i < snapshot.Length; i++)
        {
            var gap = snapshot[i] - snapshot[i - 1];
            Assert.True(gap <= period * 3,
                $"a {gap}ms gap appeared at tick {i} of a {period}ms schedule");
        }
    }

    /// <summary>
    /// Guards against a scheduler that falls seconds behind, which would be unusable even on
    /// a loaded machine. The real jitter figure is measured by the spike, not asserted here.
    /// </summary>
    [Fact]
    public void TimerLatenessStaysBounded()
    {
        const int period = 50;
        const int window = 900;

        using var timer = new PreciseTimer();
        var clock = Stopwatch.StartNew();
        var stamps = new List<long>();

        timer.Schedule(() =>
        {
            lock (stamps) stamps.Add(clock.ElapsedMilliseconds);
        }, 0, period);

        while (clock.ElapsedMilliseconds < window) Thread.Sleep(10);
        timer.CancelAll();

        lock (stamps)
        {
            for (var i = 1; i < stamps.Count; i++)
            {
                var lateness = stamps[i] - stamps[i - 1] - period;
                Assert.True(lateness < 500,
                    $"tick {i} was {lateness}ms late; a scheduler this far behind is " +
                    "unusable regardless of machine load");
            }
        }
    }


    [Fact]
    public void OneShotTimerFiresExactlyOnce()
    {
        using var timer = new PreciseTimer();
        var count = 0;

        timer.ScheduleOnce(() => Interlocked.Increment(ref count), 40);
        Thread.Sleep(250);

        Assert.Equal(1, count);
    }

    [Fact]
    public void CancelledTimerDoesNotFire()
    {
        using var timer = new PreciseTimer();
        var count = 0;

        var handle = timer.Schedule(() => Interlocked.Increment(ref count), 50, 50);
        timer.Cancel(handle);
        Thread.Sleep(250);

        Assert.Equal(0, count);
        Assert.Equal(0, timer.Count);
    }

    [Fact]
    public void CancelAllClearsEverySchedule()
    {
        using var timer = new PreciseTimer();
        var count = 0;

        timer.Schedule(() => Interlocked.Increment(ref count), 0, 20);
        timer.Schedule(() => Interlocked.Increment(ref count), 0, 20);
        timer.Schedule(() => Interlocked.Increment(ref count), 0, 20);
        Thread.Sleep(80);

        timer.CancelAll();
        var snapshot = count;
        Thread.Sleep(150);

        Assert.Equal(snapshot, count);
        Assert.Equal(0, timer.Count);
    }

    [Fact]
    public void ReschedulePushesTheNextTickOut()
    {
        using var timer = new PreciseTimer();
        var count = 0;

        var handle = timer.Schedule(() => Interlocked.Increment(ref count), 20, 20);
        Thread.Sleep(120);

        timer.Reschedule(handle, 300);
        var snapshot = count;
        Thread.Sleep(150);

        Assert.Equal(snapshot, count);
    }

    // =====================================================================
    // INPUT record layout
    // =====================================================================

    [Fact]
    public void KeyboardRecordCarriesBothVirtualKeyAndScanCode()
    {
        var input = InputPoster.BuildKeyboard(Vk.D3, keyDown: true);
        Assert.Equal((uint)NativeInputType.Keyboard, input.type);

        // Raw Input consumers need the scancode path, so both fields must be populated.
        Assert.True((input.union.ki.dwFlags & NativeConsts.KEYEVENTF_SCANCODE) != 0);
        Assert.Equal((ushort)Vk.D3, input.union.ki.wVk);
        Assert.NotEqual((ushort)0, input.union.ki.wScan);
        Assert.Equal(0u, input.union.ki.dwFlags & NativeConsts.KEYEVENTF_KEYUP);
    }

    [Fact]
    public void KeyUpSetsTheKeyUpFlag()
    {
        var input = InputPoster.BuildKeyboard(Vk.D3, keyDown: false);
        Assert.True((input.union.ki.dwFlags & NativeConsts.KEYEVENTF_KEYUP) != 0);
    }

    [Theory]
    [InlineData(Vk.Left)]
    [InlineData(Vk.Right)]
    [InlineData(Vk.Up)]
    [InlineData(Vk.Down)]
    [InlineData(Vk.Home)]
    [InlineData(Vk.End)]
    [InlineData(Vk.Prior)]
    [InlineData(Vk.Next)]
    [InlineData(Vk.Insert)]
    [InlineData(Vk.Delete)]
    [InlineData(Vk.NumPadDivide)]
    [InlineData(Vk.RControl)]
    public void ExtendedKeysSetTheExtendedFlag(Vk vk)
    {
        var input = InputPoster.BuildKeyboard(vk, keyDown: true);
        Assert.True((input.union.ki.dwFlags & NativeConsts.KEYEVENTF_EXTENDEDKEY) != 0,
            $"{vk} needs KEYEVENTF_EXTENDEDKEY or it maps to the numpad");
    }

    [Theory]
    [InlineData(Vk.A)]
    [InlineData(Vk.D1)]
    [InlineData(Vk.Oem4)]
    [InlineData(Vk.Space)]
    public void OrdinaryKeysDoNotSetTheExtendedFlag(Vk vk)
    {
        var input = InputPoster.BuildKeyboard(vk, keyDown: true);
        Assert.Equal(0u, input.union.ki.dwFlags & NativeConsts.KEYEVENTF_EXTENDEDKEY);
    }

    [Fact]
    public void ScanCodeFallbackMatchesPs2Table()
    {
        // Only meaningful off-Windows, where MapVirtualKeyW is unavailable.
        if (OperatingSystem.IsWindows()) return;

        Assert.Equal(0x1E, InputPoster.FallbackScanCode(Vk.A));
        Assert.Equal(0x02, InputPoster.FallbackScanCode(Vk.D1));
        Assert.Equal(0x39, InputPoster.FallbackScanCode(Vk.Space));
        Assert.Equal(0x1A, InputPoster.FallbackScanCode(Vk.Oem4));
        Assert.Equal(0x3B, InputPoster.FallbackScanCode(Vk.F1));
    }

    [Theory]
    [InlineData(MouseButton.Left, NativeConsts.MOUSEEVENTF_LEFTDOWN, NativeConsts.MOUSEEVENTF_LEFTUP)]
    [InlineData(MouseButton.Right, NativeConsts.MOUSEEVENTF_RIGHTDOWN, NativeConsts.MOUSEEVENTF_RIGHTUP)]
    [InlineData(MouseButton.Middle, NativeConsts.MOUSEEVENTF_MIDDLEDOWN, NativeConsts.MOUSEEVENTF_MIDDLEUP)]
    public void MouseButtonFlagsAreCorrect(MouseButton button, uint downFlag, uint upFlag)
    {
        var down = InputPoster.BuildMouseButton(button, down: true);
        Assert.Equal((uint)NativeInputType.Mouse, down.type);
        Assert.Equal(downFlag, down.union.mi.dwFlags);

        var up = InputPoster.BuildMouseButton(button, down: false);
        Assert.Equal(upFlag, up.union.mi.dwFlags);
    }

    [Fact]
    public void SideButtonsUseXdownWithButtonData()
    {
        var x1 = InputPoster.BuildMouseButton(MouseButton.XButton1, down: true);
        Assert.Equal(NativeConsts.MOUSEEVENTF_XDOWN, x1.union.mi.dwFlags);
        Assert.Equal(NativeConsts.XBUTTON1, x1.union.mi.mouseData);

        var x2 = InputPoster.BuildMouseButton(MouseButton.XButton2, down: false);
        Assert.Equal(NativeConsts.MOUSEEVENTF_XUP, x2.union.mi.dwFlags);
        Assert.Equal(NativeConsts.XBUTTON2, x2.union.mi.mouseData);
    }

    [Fact]
    public void WheelUsesHundredAndTwentyUnitNotches()
    {
        var up = InputPoster.BuildWheel(WheelDirection.Up);
        Assert.Equal(NativeConsts.MOUSEEVENTF_WHEEL, up.union.mi.dwFlags);
        Assert.Equal(120 * 3, unchecked((int)up.union.mi.mouseData));

        var down = InputPoster.BuildWheel(WheelDirection.Down);
        Assert.Equal(-120 * 3, unchecked((int)down.union.mi.mouseData));
    }

    [Fact]
    public void InputStructIsTheCorrectSize()
    {
        // sizeof(INPUT) is 40 bytes on x64; a wrong cbSize makes SendInput fail outright.
        Assert.Equal(40, NativeMethods.InputSize);
        Assert.Equal(32, System.Runtime.InteropServices.Marshal.SizeOf<InputUnion>());
    }

    [Fact]
    public void PostingIsANoOpOffWindows()
    {
        if (OperatingSystem.IsWindows()) return;

        // Must not throw; the Windows entry points are unreachable here.
        Assert.False(InputPoster.PostKey(Models.InputKey.FromKey(Vk.A)));
        Assert.False(InputPoster.PostLeftClick());
        Assert.False(InputPoster.PostWheel(WheelDirection.Up));
    }
}
