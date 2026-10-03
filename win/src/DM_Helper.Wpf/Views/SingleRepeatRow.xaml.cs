using System.Windows;
using System.Windows.Controls;
using DM_Helper.Core.Models;

namespace DM_Helper.Wpf.Views;

/// <summary>
/// One single-repeat row: hold <see cref="ToggleBox"/> to spam <see cref="ActionBox"/> every
/// <see cref="DelayBox"/> ms.
/// </summary>
public partial class SingleRepeatRow : UserControl
{
    public SingleRepeatRow()
    {
        InitializeComponent();

        DelayBox.TextChanged += (_, _) => Changed?.Invoke(this, EventArgs.Empty);
        EnabledBox.Checked += (_, _) => Changed?.Invoke(this, EventArgs.Empty);
        EnabledBox.Unchecked += (_, _) => Changed?.Invoke(this, EventArgs.Empty);
        NoteBox.TextChanged += (_, _) => Changed?.Invoke(this, EventArgs.Empty);
    }

    public int Index { get; set; }

    public event EventHandler? Changed;

    public void Load(InputKey toggle, InputKey action, int delay, bool enabled, string note)
    {
        ToggleBox.InputKey = toggle;
        ActionBox.InputKey = action;
        DelayBox.Text = delay.ToString();
        EnabledBox.IsChecked = enabled;
        NoteBox.Text = note;
    }

    public (InputKey Toggle, InputKey Action, int Delay, bool Enabled, string Note) Save() =>
        (ToggleBox.InputKey,
         ActionBox.InputKey,
         int.TryParse(DelayBox.Text, out var d) ? d : 0,
         EnabledBox.IsChecked == true,
         NoteBox.Text ?? "");
}
