using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using DM_Helper.Core.Interop;
using DM_Helper.Core.Models;

namespace DM_Helper.Wpf.Controls;

/// <summary>
/// Click-to-bind input field. Windows counterpart of <c>D3KeyTextField.m</c>.
///
/// Two capture paths are wired up on purpose, mirroring the macOS implementation:
/// a local WPF handler (works with no privileges) and the low-level hook (catches mouse
/// buttons and side buttons even when the pointer is over the game). The hook path is only
/// armed while this box has focus.
/// </summary>
public partial class KeyCaptureBox : UserControl
{
    private InputKey _previous = InputKey.Empty;
    private bool _capturing;

    public KeyCaptureBox()
    {
        InitializeComponent();
        Focusable = true;
        Cursor = Cursors.Hand;
    }

    /// <summary>The bound input. Setting it raises <see cref="InputKeyChanged"/>.</summary>
    public InputKey InputKey
    {
        get => (InputKey)GetValue(InputKeyProperty);
        set => SetValue(InputKeyProperty, value);
    }

    public static readonly DependencyProperty InputKeyProperty = DependencyProperty.Register(
        nameof(InputKey), typeof(InputKey), typeof(KeyCaptureBox),
        new PropertyMetadata(InputKey.Empty, OnInputKeyChanged));

    /// <summary>Raised when the user binds a new input.</summary>
    public event EventHandler<InputKey>? InputKeyChanged;

    /// <summary>Placeholder shown while waiting for a key press.</summary>
    public string Placeholder { get; set; } = LocalizationPlaceholder;

    public static string LocalizationPlaceholder { get; set; } = "<키 입력 대기 (ESC/Del: 비움)>";

    private static void OnInputKeyChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        var box = (KeyCaptureBox)d;
        var key = (InputKey)e.NewValue;
        box.Tag = key.IsEmpty ? string.Empty : key.DisplayString;
        box.ToolTip = key.IsEmpty ? null : key.DisplayString;
    }

    protected override void OnMouseLeftButtonDown(MouseButtonEventArgs e)
    {
        base.OnMouseLeftButtonDown(e);
        Focus();
        e.Handled = true;
    }

    protected override void OnGotKeyboardFocus(KeyboardFocusChangedEventArgs e)
    {
        base.OnGotKeyboardFocus(e);
        if (e.NewFocus is not KeyCaptureBox) BeginCapture();
    }

    protected override void OnLostKeyboardFocus(KeyboardFocusChangedEventArgs e)
    {
        base.OnLostKeyboardFocus(e);

        if (!_capturing) return;

        // Moving focus between a TextBlock and the box inside the same template would
        // otherwise cancel the capture the user just started.
        if (e.NewFocus is KeyCaptureBox or Border or TextBlock) return;

        _capturing = false;
        App.Services?.Hooks.StopCapture();

        // Focus left without binding anything: restore whatever was there before.
        SetKey(_previous);
    }

    private void BeginCapture()
    {
        if (_capturing) return;

        _capturing = true;
        _previous = InputKey;
        Tag = LocalizationPlaceholder;
        ToolTip = "ESC 또는 Delete를 누르면 비워집니다";

        var hook = App.Services?.Hooks;
        if (hook is null) return;

        hook.CaptureHandler = OnGlobalCapture;
        hook.StartCapture();
    }

    private bool OnGlobalCapture(InputEvent evt)
    {
        // Only accept a press; the release is noise for binding purposes.
        if (!evt.IsDown || evt.IsRepeat) return false;

        var key = evt.Key;
        if (key.IsEmpty) return false;

        // A left click is how the user interacts with the UI, so it can never be the
        // binding they just captured.
        if (key.Type == InputType.MouseButton && key.MouseButton == MouseButton.Left) return false;

        Dispatcher.Invoke(() =>
        {
            _capturing = false;
            App.Services?.Hooks.StopCapture();
            SetKey(key);
        });

        // Consume it so a stray mouse button cannot also drive the macro mid-binding.
        return true;
    }

    protected override void OnKeyDown(KeyEventArgs e)
    {
        base.OnKeyDown(e);

        if (!_capturing)
        {
            // Space or Enter on an unfocused field would otherwise do nothing useful.
            return;
        }

        switch (e.Key)
        {
            case Key.Escape:
            case Key.Delete:
            case Key.Back:
                _capturing = false;
                App.Services?.Hooks.StopCapture();
                SetKey(InputKey.Empty);
                e.Handled = true;
                return;

            case Key.LeftShift or Key.RightShift:
            case Key.LeftCtrl or Key.RightCtrl:
            case Key.LeftAlt or Key.RightAlt:
            case Key.LWin or Key.RWin:
            case Key.CapsLock or Key.Pause:
            case Key.None:
                // Reserved keys cannot be bound; ignore rather than poison the profile.
                e.Handled = true;
                return;
        }

        var vk = ToVirtualKey(e.Key);
        if (vk is null)
        {
            e.Handled = true;
            return;
        }

        _capturing = false;
        App.Services?.Hooks.StopCapture();
        SetKey(InputKey.FromKey(vk.Value));
        e.Handled = true;
    }

    private void SetKey(InputKey key)
    {
        InputKey = key;
        InputKeyChanged?.Invoke(this, key);
    }

    /// <summary>Maps a WPF <see cref="Key"/> onto a Windows virtual-key code.</summary>
    internal static Vk? ToVirtualKey(Key key)
    {
        // A-Z
        if (key is >= Key.A and <= Key.Z) return (Vk)(ushort)(0x41 + (key - Key.A));

        // D0-D9
        if (key is >= Key.D0 and <= Key.D9) return (Vk)(ushort)(0x30 + (key - Key.D0));

        // NumPad0-NumPad9
        if (key is >= Key.NumPad0 and <= Key.NumPad9) return (Vk)(ushort)(0x60 + (key - Key.NumPad0));

        // F1-F24
        if (key is >= Key.F1 and <= Key.F24) return (Vk)(ushort)(0x70 + (key - Key.F1));

        return key switch
        {
            Key.Space => Vk.Space,
            Key.Enter => Vk.Enter,
            Key.Tab => Vk.Tab,
            Key.Back => Vk.Backspace,
            Key.Escape => Vk.Escape,
            Key.Insert => Vk.Insert,
            Key.Delete => Vk.Delete,
            Key.Home => Vk.Home,
            Key.End => Vk.End,
            Key.PageUp => Vk.Prior,
            Key.PageDown => Vk.Next,
            Key.Left => Vk.Left,
            Key.Right => Vk.Right,
            Key.Up => Vk.Up,
            Key.Down => Vk.Down,

            Key.OemComma => Vk.OemComma,
            Key.OemPeriod => Vk.OemPeriod,
            Key.OemQuestion => Vk.Oem2,
            Key.OemSemicolon => Vk.Semicolon,
            Key.OemQuotes => Vk.Oem7,
            Key.OemOpenBrackets => Vk.Oem4,
            Key.OemCloseBrackets => Vk.Oem6,
            Key.OemPipe => Vk.Oem5,
            Key.OemPlus => Vk.OemPlus,
            Key.OemMinus => Vk.OemMinus,
            Key.OemTilde => Vk.Oem3,

            Key.Add => Vk.NumPadAdd,
            Key.Subtract => Vk.NumPadSubtract,
            Key.Multiply => Vk.NumPadMultiply,
            Key.Divide => Vk.NumPadDivide,
            Key.Decimal => Vk.NumPadDecimal,

            Key.NumLock => Vk.NumLock,
            Key.Scroll => Vk.Scroll,
            Key.Pause => Vk.Pause,
            Key.CapsLock => Vk.CapsLock,
            Key.ImeProcessed => null,

            _ => null,
        };
    }
}
