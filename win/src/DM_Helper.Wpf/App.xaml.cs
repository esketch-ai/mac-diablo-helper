using System.Windows;
using Microsoft.Win32;
using DM_Helper.Core.Interop;
using DM_Helper.Wpf.Services;

namespace DM_Helper.Wpf;

public partial class App : Application
{
    /// <summary>Shared services, created once at startup.</summary>
    public static AppServices Services { get; private set; } = null!;

    protected override void OnStartup(StartupEventArgs e)
    {
        // Physical-pixel coordinates are required before any window is created.
        Monitors.EnsurePerMonitorDpiAwareness();

        Services = new AppServices();

        ApplyTheme();

        SystemEvents.UserPreferenceChanged += OnUserPreferenceChanged;

        base.OnStartup(e);
    }

    protected override void OnExit(ExitEventArgs e)
    {
        Services.Dispose();
        base.OnExit(e);
    }

    private void OnUserPreferenceChanged(object sender, UserPreferenceChangedEventArgs e)
    {
        if (e.Category == UserPreferenceCategory.General) ApplyTheme();
    }

    /// <summary>
    /// Follows the Windows app theme. The macOS build listened for
    /// <c>AppleInterfaceThemeChangedNotification</c>; this is the equivalent.
    /// </summary>
    private void ApplyTheme()
    {
        var dark = IsDarkTheme();
        var uri = new Uri($"Themes/{(dark ? "Dark" : "Light")}.xaml", UriKind.Relative);

        Resources.MergedDictionaries.Clear();
        Resources.MergedDictionaries.Add(new ResourceDictionary { Source = uri });
    }

    private static bool IsDarkTheme()
    {
        try
        {
            using var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(
                @"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
            return key?.GetValue("AppsUseLightTheme") is int light && light == 0;
        }
        catch
        {
            return false;
        }
    }
}
