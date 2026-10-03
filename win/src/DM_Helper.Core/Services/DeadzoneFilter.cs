using DM_Helper.Core.Interop;
using DM_Helper.Core.Models;

namespace DM_Helper.Core.Services;

/// <summary>
/// Anti-disturbance filter: suppresses a skill click when the cursor is over a piece of
/// in-game UI, so a left-click skill never accidentally opens the map, inventory or an
/// action-bar slot.
///
/// Direct port of <c>D3DeadzoneFilter.m</c>, with <c>CGDisplayBounds</c> replaced by
/// <c>MonitorFromPoint</c> / <c>GetMonitorInfo</c>. Coordinates are physical pixels, which
/// requires per-monitor DPI awareness to be set at startup.
/// </summary>
public static class DeadzoneFilter
{
    /// <summary>
    /// Cached cursor position. Tests set this to drive the filter deterministically; when
    /// null the real cursor position is queried.
    /// </summary>
    internal static (int X, int Y)? CursorOverride;

    /// <summary>
    /// Cached monitor geometry. Without this the filter asks the OS, so a test asserting on
    /// a 1920x1080 layout would silently compute against whatever display the runner
    /// happens to have - which is how the same test passed on macOS and failed on a
    /// Windows runner with a different virtual display size.
    /// </summary>
    internal static MonitorRect? MonitorOverride;

    public static bool IsCursorInUiDeadzone(string? resolutionMode) => Evaluate(Cursor(), resolutionMode);

    private static (int X, int Y) Cursor()
    {
        if (CursorOverride is { } c) return c;

        if (!OperatingSystem.IsWindows()) return (0, 0);

        return NativeMethods.GetCursorPos(out var pt) ? (pt.X, pt.Y) : (0, 0);
    }

    /// <summary>Pure form of the check, exposed so it can be tested without a real cursor.</summary>
    internal static bool Evaluate((int X, int Y) cursor, string? resolutionMode) =>
        Evaluate(cursor, resolutionMode, MonitorGeometry(cursor.X, cursor.Y));

    /// <summary>
    /// Fully deterministic form: monitor geometry is supplied, so resolution pinning can be
    /// verified without a multi-monitor desktop.
    /// </summary>
    internal static bool Evaluate(
        (int X, int Y) cursor, string? resolutionMode, MonitorRect mon)
    {
        double relX = cursor.X - mon.Left;
        double relY = cursor.Y - mon.Top;
        double w = mon.Width;
        double h = mon.Height;

        // A pinned resolution rescales the cursor to that game's render space.
        if (DeadzoneFilterOptions.Resolve(resolutionMode) is { } fixedRes)
        {
            relX = relX / w * fixedRes.Width;
            relY = relY / h * fixedRes.Height;
            w = fixedRes.Width;
            h = fixedRes.Height;
        }

        if (w <= 0 || h <= 0) return false;

        // ---- 1. Bottom action bar / skill bar / resource glob ----
        var barStartY = h * 0.80;
        var barStartX = w * 0.22;
        var barEndX = w * 0.78;
        if (relY >= barStartY && relX >= barStartX && relX <= barEndX) return true;

        // ---- 2. Minimap, top right ----
        var miniMapStartX = w * 0.85;
        var miniMapEndY = h * 0.22;
        if (relX >= miniMapStartX && relY <= miniMapEndY) return true;

        return false;
    }

    private static MonitorRect MonitorGeometry(int x, int y)
    {
        if (MonitorOverride is { } forced) return forced;

        if (OperatingSystem.IsWindows())
        {
            var mon = Monitors.MonitorForPoint(x, y);
            if (mon is not null) return mon.Value;
        }

        // Off-Windows, or when the query fails, assume a 1920x1080 display at the origin
        // so the ratio maths stays exercisable from tests.
        return new MonitorRect(0, 0, 1920, 1080);
    }
}
