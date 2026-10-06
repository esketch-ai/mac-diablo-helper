using System.Linq;
using System.Windows;
using System.Windows.Controls;
using DM_Helper.Core.Models;

namespace DM_Helper.Wpf.Views;

/// <summary>One row of the opener sequence editor (key, delay, repeat count, description).</summary>
public partial class OpenerStepRow : UserControl
{
    private static readonly int[] RepeatOptions = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 30];

    public OpenerStepRow()
    {
        InitializeComponent();

        foreach (var opt in RepeatOptions) RepeatBox.Items.Add(opt);

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
        RepeatBox.SelectedItem = RepeatOptions.Contains(step.RepeatCount) ? step.RepeatCount : 1;
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
