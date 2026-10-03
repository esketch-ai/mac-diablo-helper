using System.Windows;
using System.Windows.Controls;
using DM_Helper.Core.Models;

namespace DM_Helper.Wpf.Controls;

/// <summary>
/// One of the eight skill slots. Emits <see cref="Changed"/> whenever any field is edited,
/// so the window can push the value into the engine and schedule a save.
/// </summary>
public partial class SkillRowControl : UserControl
{
    private bool _updating;

    public SkillRowControl()
    {
        InitializeComponent();

        ModeBox.ItemsSource = new[]
        {
            new ModeOption(LanguageKey.Spam, "연타 (Spam)"),
            new ModeOption(LanguageKey.Hold, "홀드 (Hold)"),
        };
        ModeBox.DisplayMemberPath = "Label";
        ModeBox.SelectedIndex = 0;
    }

    /// <summary>1-based slot number, shown to the user.</summary>
    public int Slot { get; set; }

    /// <summary>Raised on any edit.</summary>
    public event EventHandler? Changed;

    public void Load(InputKey key, int delay, bool linkedToSpecialKey, bool hold)
    {
        _updating = true;
        try
        {
            CheckBox.IsChecked = linkedToSpecialKey;
            KeyBox.InputKey = key;
            DelayBox.Text = delay.ToString();
            ModeBox.SelectedIndex = hold ? 1 : 0;
            ApplyHoldVisibility();
        }
        finally
        {
            _updating = false;
        }
    }

    public (InputKey Key, int Delay, bool Check, bool Hold) Save() =>
        (KeyBox.InputKey,
         int.TryParse(DelayBox.Text, out var d) ? d : 0,
         CheckBox.IsChecked == true,
         ModeBox.SelectedIndex == 1);

    private void OnChanged(object sender, RoutedEventArgs e)
    {
        if (_updating) return;

        ApplyHoldVisibility();
        Changed?.Invoke(this, EventArgs.Empty);
    }

    private void OnKeyChanged(object? sender, InputKey key)
    {
        if (_updating) return;
        Changed?.Invoke(this, EventArgs.Empty);
    }

    private void ApplyHoldVisibility()
    {
        var hold = ModeBox.SelectedIndex == 1;

        DelayBox.Visibility = hold ? Visibility.Collapsed : Visibility.Visible;
        UnitLabel.Visibility = hold ? Visibility.Collapsed : Visibility.Visible;

        // A hold-mode skill has no interval, so clear it rather than leave a stale value
        // that would silently apply if the user switched back to spam.
        if (hold) DelayBox.Text = "0";
    }

    private sealed record ModeOption(LanguageKey Key, string Label);

    private enum LanguageKey
    {
        Spam,
        Hold,
    }
}
