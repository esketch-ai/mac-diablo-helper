using System.Drawing;
using System.IO;
using System.Windows.Forms;
using DM_Helper.Core.Engine;
using DM_Helper.Core.Interop;
using DM_Helper.Core.Services;
using CoreLocalization = DM_Helper.Core.Services.Localization;

namespace DM_Helper.Wpf.Services;

/// <summary>
/// Tray icon - the Windows counterpart of the macOS <c>NSStatusBar</c> menu in
/// <c>AppDelegate.m</c>.
///
/// WinForms' <see cref="NotifyIcon"/> is used because WPF ships no tray icon of its own,
/// and a third-party package for one icon would be a poor trade in an app that otherwise
/// has zero external dependencies.
/// </summary>
public sealed class TrayIconController : IDisposable
{
    private readonly NotifyIcon _notify;
    private readonly ContextMenuStrip _menu = new();
    private readonly ToolStripMenuItem _statusItem = new("○ 정지됨") { Enabled = false };
    private readonly ToolStripMenuItem _toggleItem = new("▶ 동작 시작");
    private readonly ToolStripMenuItem _openerItem = new("준비 시퀀스 실행");
    private readonly ToolStripMenuItem _langItem = new("언어");

    private readonly Icon _idleIcon;
    private readonly Icon _runningIcon;
    private bool _disposed;

    public event Action? ToggleRequested;
    public event Action? OpenerRequested;
    public event Action? SettingsRequested;
    public event Action? PresetHubRequested;
    public event Action? GuideRequested;
    public event Action? QuitRequested;

    /// <summary>
    /// Drops every subscriber. The tray outlives the settings window, so the window must
    /// detach on close or a later click would dispatch into a dead view.
    /// </summary>
    public void ClearHandlers()
    {
        ToggleRequested = null;
        OpenerRequested = null;
        SettingsRequested = null;
        PresetHubRequested = null;
        GuideRequested = null;
        QuitRequested = null;
    }

    public TrayIconController()
    {
        _statusItem.Font = new Font(_statusItem.Font, FontStyle.Bold);

        AddLanguageItem("자동 (시스템)", LanguageMode.Auto);
        AddLanguageItem("한국어", LanguageMode.Korean);
        AddLanguageItem("English", LanguageMode.English);

        _menu.Items.Add(_statusItem);
        _menu.Items.Add(new ToolStripSeparator());
        _menu.Items.Add(_toggleItem);
        _menu.Items.Add(_openerItem);
        _menu.Items.Add(new ToolStripSeparator());
        _menu.Items.Add("설정…", null, (_, _) => SettingsRequested?.Invoke());
        _menu.Items.Add("시트 공유…", null, (_, _) => PresetHubRequested?.Invoke());
        _menu.Items.Add("사용 가이드", null, (_, _) => GuideRequested?.Invoke());
        _menu.Items.Add(new ToolStripSeparator());
        _menu.Items.Add(_langItem);
        _menu.Items.Add(new ToolStripSeparator());
        _menu.Items.Add("종료", null, (_, _) => QuitRequested?.Invoke());

        _toggleItem.Click += (_, _) => ToggleRequested?.Invoke();
        _openerItem.Click += (_, _) => OpenerRequested?.Invoke();

        _idleIcon = LoadIcon("d3a_statusbar.ico") ?? SystemIcons.Information;
        _runningIcon = LoadIcon("d3a_statusbar_active.ico") ?? MakeActiveVariant(_idleIcon);

        _notify = new NotifyIcon
        {
            Icon = _idleIcon,
            Text = "DM_Helper",
            Visible = true,
            ContextMenuStrip = _menu,
        };

        _notify.DoubleClick += (_, _) => SettingsRequested?.Invoke();
    }

    private void AddLanguageItem(string label, LanguageMode mode)
    {
        var item = new ToolStripMenuItem(label) { Tag = mode, CheckOnClick = false };
        item.Click += (_, _) => CoreLocalization.Instance.Mode = mode;
        _langItem.DropDownItems.Add(item);
    }

    /// <summary>Reflects the engine state in the tray icon, tooltip and menu labels.</summary>
    public void UpdateState(bool running, bool openerRunning)
    {
        if (_disposed) return;

        _notify.Icon = running ? _runningIcon : _idleIcon;

        _statusItem.Text = openerRunning
            ? "⚡ 준비 시퀀스 실행 중"
            : running ? "● 동작 중" : "○ 정지됨";

        _toggleItem.Text = running ? "■ 동작 중지" : "▶ 동작 시작";

        // The shell truncates the tooltip past 63 characters.
        _notify.Text = openerRunning ? "DM_Helper - 준비 시퀀스 실행 중" : "DM_Helper";
    }

    public void ShowBalloon(string title, string text, bool isError)
    {
        if (_disposed) return;

        _notify.BalloonTipTitle = title;
        _notify.BalloonTipText = text;
        _notify.BalloonTipIcon = isError ? ToolTipIcon.Error : ToolTipIcon.Info;
        _notify.ShowBalloonTip(5000);
    }

    /// <summary>Re-reads language-dependent labels and tick marks.</summary>
    public void RebuildMenu()
    {
        if (_disposed) return;

        var l10n = CoreLocalization.Instance;

        _langItem.Text = l10n.IsKorean ? "언어" : "Language";
        _openerItem.Text = l10n.T("opener_btn");

        var selected = l10n.Mode;
        foreach (ToolStripItem item in _langItem.DropDownItems)
        {
            if (item is ToolStripMenuItem menu && menu.Tag is LanguageMode mode)
                menu.Checked = mode == selected;
        }
    }

    private static Icon LoadIcon(string fileName)
    {
        var path = Path.Combine(AppContext.BaseDirectory, "Assets", fileName);
        return File.Exists(path) ? new Icon(path) : null!;
    }

    /// <summary>
    /// Builds the "running" variant by compositing a green dot behind the idle icon, so
    /// only one asset has to ship and the two states stay visually consistent.
    /// </summary>
    private static Icon MakeActiveVariant(Icon source)
    {
        using var bitmap = new Bitmap(source.Width, source.Height);

        using (var g = Graphics.FromImage(bitmap))
        {
            g.Clear(Color.Transparent);

            using (var tint = new SolidBrush(Color.FromArgb(235, 26, 158, 75)))
                g.FillEllipse(tint, 1, 1, source.Width - 2, source.Height - 2);

            g.DrawIcon(source, 0, 0);
        }

        // Icon.FromHandle does not own the handle, so the clone keeps the bitmap alive.
        return (Icon)Icon.FromHandle(bitmap.GetHicon()).Clone();
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;

        _notify.Visible = false;
        _notify.Dispose();
        _menu.Dispose();

        if (!ReferenceEquals(_idleIcon, _runningIcon)) _runningIcon.Dispose();
        _idleIcon.Dispose();
    }
}

/// <summary>
/// Application-wide singletons, wired up once at startup so the views stay passive and the
/// engine has exactly one owner.
/// </summary>
public sealed class AppServices : IDisposable
{
    public ConfigStore Configs { get; } = new();
    public HelperEngine Engine { get; } = new();
    public InputHookService Hooks { get; } = new();
    public GoogleSheetClient Sheet { get; } = new();
    public TrayIconController Tray { get; } = new();

    public CoreLocalization L10n => CoreLocalization.Instance;

    public AppServices()
    {
        CoreLocalization.LanguageChanged += _ => Tray.RebuildMenu();
    }

    /// <summary>Loads profile 1 into the engine and starts global capture.</summary>
    public void Initialize()
    {
        Engine.Config = Configs.Load("1");

        if (!Hooks.Start())
        {
            Tray.ShowBalloon(
                "입력 감지 실패",
                "저수준 훅을 설치하지 못했습니다. 관리자 권한으로 실행 중인지 확인하세요.",
                isError: true);
        }

        Hooks.EventReceived += OnInput;
    }

    private void OnInput(InputEvent evt) => Engine.HandleInput(evt);

    public void Save(string profileId) => Configs.Save(Engine.Config, profileId);

    public void Dispose()
    {
        Hooks.EventReceived -= OnInput;
        Hooks.Dispose();
        Engine.Dispose();
        Tray.Dispose();
    }
}
