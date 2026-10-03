using System.Windows;

namespace DM_Helper.Wpf.Views;

/// <summary>Prompt for the Apps Script Web App deployment URL used to publish presets.</summary>
public partial class WebAppUrlDialog : Window
{
    public WebAppUrlDialog()
    {
        InitializeComponent();
        WebAppBox.Text = App.Services.Sheet.WebAppUrl;
    }

    public string WebAppUrl => WebAppBox.Text.Trim();

    private void OnOkClick(object sender, RoutedEventArgs e)
    {
        if (string.IsNullOrWhiteSpace(WebAppBox.Text))
        {
            MessageBox.Show("URL을 입력하세요.", "Web App", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }

        DialogResult = true;
    }
}
