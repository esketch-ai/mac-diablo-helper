using DM_Helper.Core.Engine;
using DM_Helper.Core.Interop;

namespace DM_Helper.Core.Tests;

/// <summary>
/// Verifies the scheduler hits its deadlines closely enough for a 120ms rotation, and
/// that the Win32 <c>INPUT</c> records are assembled correctly.
/// </summary>
public class PrecisionAndInputRecordTests
{
    [Fact]
    public void TimerFiresRepeatedlyAtTheRequestedPeriod()
    {
        using var timer = new PreciseTimer();
        var count = 0;

        timer.Schedule(() => Interlocked.Increment(ref count), 0, 50);

        Thread.Sleep(600);
        Assert.True(count >= 8, $"expected ~12 ticks at 50ms, saw {count}");
    }

    [Fact]
    public void TimerStaysCloseToItsDeadline()
    {
        using var timer = new PreciseTimer();
        var count = 0;

        // 100ms period over ~1s: a System.Threading.Timer would typically exceed 15ms
        // lateness here on Windows 11.
        timer.Schedule(() => Interlocked.Increment(ref count), 0, 100);
        Thread.Sleep(1000);

        Assert.True(count >= 8, $"expected ~10 ticks, saw {count}");
        Assert.True(timer.MaxLatenessUs < 15_000,
            $"worst lateness was {timer.MaxLatenessUs / 1000.0:F1}ms, budget is 15ms");
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
