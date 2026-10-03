using System.Runtime.InteropServices;
using System.Text;

namespace DM_Helper.Core.Interop;

/// <summary>Replaces <c>NSWorkspace.frontmostApplication</c> for the purpose of finding the game.</summary>
public static class ForegroundWindow
{
    /// <summary>Window handle of the helper's own main window, when it exists.</summary>
    public static nint OwnWindow { get; set; }

    /// <summary>True when the helper's own UI currently has focus.</summary>
    public static bool IsOwnUiFocused =>
        OwnWindow != 0 && NativeMethods.GetForegroundWindow() == OwnWindow;

    /// <summary>Process id owning the foreground window, or 0.</summary>
    public static uint ForegroundProcessId =>
        NativeMethods.GetWindowThreadProcessId(NativeMethods.GetForegroundWindow(), out var pid) == 0
            ? 0u
            : pid;

    /// <summary>
    /// True when the named process appears to own the foreground window. Falls back to a
    /// scan of top-level windows when the foreground window is owned by a launcher shell
    /// (Battle.net hands focus to a child process shortly after launch).
    /// </summary>
    public static bool IsProcessForeground(string processName, string? windowTitleContains = null)
    {
        if (!OperatingSystem.IsWindows()) return false;

        var fg = NativeMethods.GetForegroundWindow();
        if (fg != 0 && NativeMethods.GetWindowThreadProcessId(fg, out var pid) != 0)
        {
            var name = ProcessName(pid);
            if (Matches(name, processName)) return true;
        }

        if (windowTitleContains is null) return false;

        var found = false;
        NativeMethods.EnumWindows((hWnd, _) =>
        {
            if (!NativeMethods.IsWindowVisible(hWnd)) return true;

            var len = NativeMethods.GetWindowTextLengthW(hWnd);
            if (len <= 0) return true;

            var buf = new char[len + 1];
            NativeMethods.GetWindowTextW(hWnd, buf, buf.Length);

            var title = new string(buf, 0, len);
            if (title.IndexOf(windowTitleContains, StringComparison.OrdinalIgnoreCase) < 0)
                return true;

            NativeMethods.GetWindowThreadProcessId(hWnd, out var wp);
            if (Matches(ProcessName(wp), processName)) found = true;

            return !found;
        }, IntPtr.Zero);

        return found;
    }

    private static bool Matches(string? actual, string expected) =>
        actual is not null && actual.Equals(expected, StringComparison.OrdinalIgnoreCase);

    /// <summary>Executable name (without extension) for a pid, or null.</summary>
    public static string? ProcessName(uint pid)
    {
        if (!OperatingSystem.IsWindows() || pid == 0) return null;

        var h = NativeMethods.OpenProcess(
            NativeConsts.PROCESS_QUERY_LIMITED_INFORMATION, false, pid);
        if (h == IntPtr.Zero) return null;

        try
        {
            var size = 260u;
            var buf = new char[size];
            return NativeMethods.QueryFullProcessImageNameW(h, 0, buf, ref size)
                ? Path.GetFileNameWithoutExtension(new string(buf, 0, (int)size))
                : null;
        }
        finally
        {
            NativeMethods.CloseHandle(h);
        }
    }

    /// <summary>Pids of every visible top-level window belonging to a matching executable.</summary>
    public static IReadOnlyList<uint> FindProcessIds(string processName)
    {
        var result = new List<uint>();
        if (!OperatingSystem.IsWindows()) return result;

        NativeMethods.EnumWindows((hWnd, _) =>
        {
            if (NativeMethods.GetWindowTextLengthW(hWnd) <= 0) return true;

            NativeMethods.GetWindowThreadProcessId(hWnd, out var pid);
            if (pid != 0 && Matches(ProcessName(pid), processName)) result.Add(pid);
            return true;
        }, IntPtr.Zero);

        return result;
    }

    /// <summary>Window title of the first visible window belonging to a matching executable.</summary>
    public static string? FindWindowTitle(string processName)
    {
        string? title = null;
        if (!OperatingSystem.IsWindows()) return null;

        NativeMethods.EnumWindows((hWnd, _) =>
        {
            if (!NativeMethods.IsWindowVisible(hWnd)) return true;

            var len = NativeMethods.GetWindowTextLengthW(hWnd);
            if (len <= 0) return true;

            NativeMethods.GetWindowThreadProcessId(hWnd, out var pid);
            if (!Matches(ProcessName(pid), processName)) return true;

            var buf = new char[len + 1];
            NativeMethods.GetWindowTextW(hWnd, buf, buf.Length);
            title = new string(buf, 0, len);
            return false;
        }, IntPtr.Zero);

        return title;
    }
}

/// <summary>Physical-pixel monitor geometry, replacing <c>CGDisplayBounds</c>.</summary>
public readonly record struct MonitorRect(int Left, int Top, int Width, int Height)
{
    public int Right => Left + Width;
    public int Bottom => Top + Height;
}

public static class Monitors
{
    /// <summary>
    /// Opts the process into per-monitor DPI awareness so <c>GetCursorPos</c> and
    /// <c>GetMonitorInfo</c> report physical pixels. Without this the deadzone filter
    /// breaks on any display that is not at 100% scaling.
    /// </summary>
    public static void EnsurePerMonitorDpiAwareness()
    {
        if (!OperatingSystem.IsWindows()) return;

        try
        {
            // S_OK == 0, E_ACCESSDENIED == -2147024891 (already set).
            var hr = NativeMethods.SetProcessDpiAwareness(NativeConsts.PROCESS_PER_MONITOR_DPI_AWARE);
            if (hr != 0)
                NativeMethods.SetProcessDPIAware();
        }
        catch (DllNotFoundException)
        {
            // shcore.dll is absent on Windows 8.1 and earlier.
            NativeMethods.SetProcessDPIAware();
        }
        catch (EntryPointNotFoundException)
        {
            NativeMethods.SetProcessDPIAware();
        }
    }

    /// <summary>Bounds of the monitor the cursor is currently on.</summary>
    public static MonitorRect? MonitorUnderCursor()
    {
        if (!OperatingSystem.IsWindows()) return null;
        if (!NativeMethods.GetCursorPos(out var pt)) return null;
        return MonitorForPoint(pt.X, pt.Y);
    }

    public static MonitorRect? MonitorForPoint(int x, int y)
    {
        if (!OperatingSystem.IsWindows()) return null;

        var hMon = NativeMethods.MonitorFromPoint(
            new POINT { X = x, Y = y }, NativeConsts.MONITOR_DEFAULTTONEAREST);
        if (hMon == IntPtr.Zero) return null;
        return InfoFor(hMon);
    }

    public static MonitorRect? MonitorForWindow(nint hwnd)
    {
        if (!OperatingSystem.IsWindows()) return null;
        var hMon = NativeMethods.MonitorFromWindow(hwnd, NativeConsts.MONITOR_DEFAULTTONEAREST);
        return hMon == IntPtr.Zero ? null : InfoFor(hMon);
    }

    public static IReadOnlyList<MonitorRect> All()
    {
        var list = new List<MonitorRect>();
        if (!OperatingSystem.IsWindows()) return list;

        NativeMethods.EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, (hMon, _, _, _) =>
        {
            var info = InfoFor(hMon);
            if (info is not null) list.Add(info.Value);
            return true;
        }, IntPtr.Zero);

        return list;
    }

    private static MonitorRect? InfoFor(nint hMon)
    {
        var mi = new MONITORINFO { cbSize = Marshal.SizeOf<MONITORINFO>() };
        if (!NativeMethods.GetMonitorInfoW(hMon, ref mi)) return null;

        return new MonitorRect(
            mi.rcMonitor.Left,
            mi.rcMonitor.Top,
            mi.rcMonitor.Right - mi.rcMonitor.Left,
            mi.rcMonitor.Bottom - mi.rcMonitor.Top);
    }
}
