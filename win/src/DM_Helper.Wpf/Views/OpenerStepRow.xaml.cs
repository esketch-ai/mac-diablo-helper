using System.Windows;
using System.Windows.Controls;
using DM_Helper.Core.Models;

namespace DM_Helper.Wpf.Views;

/// <summary>One row of the opener sequence editor (key, delay, repeat count, description).</summary>
public partial class OpenerStepRow : UserControl
{
    public OpenerStepRow()
    {
        InitializeComponent();

        for (var i = 1; i <= 5; i++) RepeatBox.Items.Add(i);

        DelayBox.TextChanged += (_, _) => Changed?.Invoke(this, EventArgs.Empty);
        DescriptionBox.TextChanged += (_, _) => Changed?.Invoke(this, EventArgs.Empty);
        RepeatBox.SelectionChanged += (_, _) => Changed?.Invoke(this, EventArgs.Empty);
    }

    public int Index { get; set; }

    /// <summary>Raised whenever any field in the row is edited.</summary>
    public event EventHandler? Changed;

    public void Load(OpenerStep step)
    {
        KeyBox.InputKey = step.Key;
        DelayBox.Text = step.DelayMs.ToString();
        RepeatBox.SelectedItem = Math.Clamp(step.RepeatCount, 1, 5);
        DescriptionBox.Text = step.Description;
    }

    public OpenerStep Save() => new()
    {
        Key = KeyBox.InputKey,
        DelayMs = int.TryParse(DelayBox.Text, out var d) ? d : 150,
        RepeatCount = RepeatBox.SelectedItem is int r ? r : 1,
        Description = DescriptionBox.Text ?? "",
    };
}
