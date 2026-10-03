using System.Net;
using System.Net.Http;
using System.Windows;
using System.Windows.Controls;
using DM_Helper.Core.Models;
using DM_Helper.Core.Services;
using DM_Helper.Wpf.Services;
using CoreLocalization = DM_Helper.Core.Services.Localization;

namespace DM_Helper.Wpf.Views;

/// <summary>
/// Community preset browser - the counterpart of <c>D3PresetShareWindowController.m</c>.
///
/// Reads and writes the same shared Google Sheet as the macOS build, so both platforms see
/// one pool of presets.
/// </summary>
public partial class PresetShareWindow : Window
{
    private readonly GoogleSheetClient _sheet;
    private IReadOnlyList<PresetItem> _all = Array.Empty<PresetItem>();
    private bool _updating;
    private string _allLabel = "전체";

    private static CoreLocalization L10n => CoreLocalization.Instance;

    public PresetShareWindow()
    {
        InitializeComponent();

        _sheet = App.Services.Sheet;
        SheetUrlBox.Text = _sheet.SheetUrl;

        ApplyLanguage();

        // Show whatever is cached immediately, then refresh in the background so the
        // window is never blank while the network call is in flight.
        _all = _sheet.CachedPresets.Count > 0
            ? _sheet.CachedPresets
            : GoogleSheetClient.SeedPresets();

        RebuildFilters();
        RefreshGrid();
        _ = RefreshAsync();
    }

    // =====================================================================
    // Data
    // =====================================================================

    private async Task RefreshAsync()
    {
        StatusLabel.Text = L10n.IsKorean ? "시트에서 불러오는 중…" : "Loading from the sheet...";

        var ok = await _sheet.RefreshAsync().ConfigureAwait(true);

        if (ok)
        {
            _all = _sheet.CachedPresets;
            StatusLabel.Text = $"{_all.Count} presets";
        }
        else
        {
            StatusLabel.Text = L10n.IsKorean
                ? (_sheet.CachedPresets.Count > 0
                    ? $"오프라인 - 캐시된 {_all.Count}개 표시 중"
                    : "시트를 불러오지 못했습니다. 네트워크 연결을 확인하세요.")
                : (_sheet.CachedPresets.Count > 0
                    ? $"Offline - showing {_all.Count} cached presets"
                    : "Could not reach the sheet. Check your network.");
        }

        RebuildFilters();
        RefreshGrid();
    }

    private void RebuildFilters()
    {
        _updating = true;
        try
        {
            var classes = _all.Select(p => p.Class).Distinct().OrderBy(c => c).ToArray();
            var seasons = _all.Select(p => p.Season).Distinct().OrderBy(s => s).ToArray();

            ClassFilter.ItemsSource = new[] { _allLabel }.Concat(classes).ToArray();
            ClassFilter.SelectedIndex = 0;

            SeasonFilter.ItemsSource = new[] { _allLabel }.Concat(seasons).ToArray();
            SeasonFilter.SelectedIndex = 0;
        }
        finally
        {
            _updating = false;
        }
    }

    private void RefreshGrid()
    {
        IEnumerable<PresetItem> query = _all;

        if (ClassFilter.SelectedIndex > 0 && ClassFilter.SelectedItem is string cls && cls != _allLabel)
            query = query.Where(p => p.Class == cls);

        if (SeasonFilter.SelectedIndex > 0 && SeasonFilter.SelectedItem is string season && season != _allLabel)
            query = query.Where(p => p.Season == season);

        var rows = query.ToArray();

        PresetGrid.ItemsSource = rows;
        EmptyLabel.Visibility = rows.Length == 0 ? Visibility.Visible : Visibility.Collapsed;
        LoadButton.IsEnabled = rows.Any(r => r.IsLoadable);
    }

    private PresetItem? Selected => PresetGrid.SelectedItem as PresetItem;

    // =====================================================================
    // Handlers
    // =====================================================================

    private void OnFilterChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_updating) return;
        RefreshGrid();
    }

    private void OnSheetUrlChanged(object sender, TextChangedEventArgs e)
    {
        if (_updating) return;
        _sheet.SetSheetUrl(SheetUrlBox.Text);
    }

    private async void OnRefreshClick(object sender, RoutedEventArgs e) => await RefreshAsync();

    private void OnLoadClick(object sender, RoutedEventArgs e)
    {
        if (Selected is not { IsLoadable: true } preset) return;

        var engine = App.Services.Engine;
        preset.ApplyTo(engine.Config);

        // Copy the matching class preset's key timings across, so a community build loads
        // with sensible numbers rather than only the keys.
        var kind = PresetKindFor(preset.PresetName);
        if (kind is not null)
        {
            var template = KeyConfig.ForPreset(kind.Value);
            for (var i = 0; i < 5; i++)
            {
                if (preset.SkillKeys[i] is null) engine.Config.SkillDelays[i] = template.SkillDelay(i);
            }
        }

        App.Services.Save("1");

        MessageBox.Show(
            L10n.IsKorean
                ? $"'{preset.PresetName}' 프리셋을 프로필 1에 불러왔습니다.\n\n{preset.Description}"
                : $"Loaded '{preset.PresetName}' into profile 1.\n\n{preset.Description}",
            "불러오기 완료", MessageBoxButton.OK, MessageBoxImage.Information);

        Close();
    }

    private static KeyConfig.PresetKind? PresetKindFor(string presetName)
    {
        if (presetName.Contains("악마술사") || presetName.Contains("Warlock", StringComparison.OrdinalIgnoreCase))
            return KeyConfig.PresetKind.Warlock;
        if (presetName.Contains("원소술사") || presetName.Contains("Sorcerer", StringComparison.OrdinalIgnoreCase))
            return KeyConfig.PresetKind.Sorcerer;
        if (presetName.Contains("강령술사") || presetName.Contains("Necromancer", StringComparison.OrdinalIgnoreCase))
            return KeyConfig.PresetKind.Necromancer;
        if (presetName.Contains("야만용사") || presetName.Contains("Barbarian", StringComparison.OrdinalIgnoreCase))
            return KeyConfig.PresetKind.Barbarian;
        if (presetName.Contains("도적") || presetName.Contains("Rogue", StringComparison.OrdinalIgnoreCase))
            return KeyConfig.PresetKind.Rogue;
        if (presetName.Contains("혼령사") || presetName.Contains("Spiritborn", StringComparison.OrdinalIgnoreCase))
            return KeyConfig.PresetKind.Spiritborn;
        return null;
    }

    private async void OnShareClick(object sender, RoutedEventArgs e)
    {
        if (Selected is not { } preset)
        {
            MessageBox.Show(
                L10n.IsKorean ? "공유할 프리셋을 먼저 선택하세요." : "Select a preset to share first.",
                "공유", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }

        if (string.IsNullOrWhiteSpace(_sheet.WebAppUrl))
        {
            var input = new WebAppUrlDialog { Owner = this };
            if (input.ShowDialog() != true || string.IsNullOrWhiteSpace(input.WebAppUrl))
            {
                MessageBox.Show(
                    L10n.IsKorean
                        ? "Apps Script Web App URL 이 설정되지 않았습니다.\n시트에서 '확장 프로그램 > Apps Script > 배포 > 웹 앱'으로 배포한 URL을 입력하세요."
                        : "No Apps Script Web App URL is configured. Deploy the sheet script as a web app and enter that URL.",
                    "공유", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }

            _sheet.SetWebAppUrl(input.WebAppUrl.Trim());
        }

        try
        {
            var status = await _sheet.PublishAsync(preset);
            StatusLabel.Text = $"✓ {(int)status}";
        }
        catch (InvalidOperationException ex)
        {
            MessageBox.Show(ex.Message, "공유", MessageBoxButton.OK, MessageBoxImage.Warning);
        }
        catch (HttpRequestException)
        {
            MessageBox.Show(
                L10n.IsKorean ? "네트워크 오류로 공유하지 못했습니다." : "Network error while publishing.",
                "공유", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    private void OnCopyClick(object sender, RoutedEventArgs e)
    {
        if (Selected is not { } preset) return;

        Clipboard.SetText(preset.ToTsvRow());
        StatusLabel.Text = L10n.IsKorean
            ? "클립보드에 복사되었습니다 (Ctrl+V로 시트에 붙여넣기)"
            : "Copied to the clipboard (Ctrl+V into the sheet)";
    }

    private void OnCloseClick(object sender, RoutedEventArgs e) => Close();

    private void ApplyLanguage()
    {
        var ko = L10n.IsKorean;

        Title = ko ? "구글 시트 프리셋 공유 센터" : "Community Preset Hub";

        RefreshButton.Content = ko ? "새로고침" : "Refresh";
        LoadButton.Content = ko ? "슬롯으로 불러오기" : "Load into slots";
        ShareButton.Content = ko ? "내 빌드 공유" : "Share mine";
        CopyButton.Content = ko ? "행 복사" : "Copy row";
        ClassLabel.Text = ko ? "직업" : "Class";
        SeasonLabel.Text = ko ? "시즌" : "Season";
        SheetLabel.Text = ko ? "시트" : "Sheet";
        CloseButton.Content = ko ? "닫기" : "Close";
        EmptyLabel.Text = ko ? "표시할 프리셋이 없습니다." : "No presets to show.";

        // "전체" is the sentinel used by the filters; keep it translated.
        var koAll = ko ? "전체" : "All";
        _allLabel = koAll;
        RebuildFilters();

        // Headers are authored in Korean; map them by index so the translation stays in one
        // place instead of being scattered through the XAML.
        var headers = ko
            ? new[] { "작성자", "직업", "빌드" }
            : new[] { "Author", "Class", "Build" };

        for (var i = 0; i < PresetGrid.Columns.Count && i < headers.Length; i++)
            PresetGrid.Columns[i].Header = headers[i];
    }
}
