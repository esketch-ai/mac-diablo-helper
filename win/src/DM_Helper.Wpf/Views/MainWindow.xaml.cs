using System.Globalization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Threading;
using DM_Helper.Core.Engine;
using DM_Helper.Core.Interop;
using DM_Helper.Core.Models;
using DM_Helper.Core.Services;
using DM_Helper.Wpf.Controls;
using DM_Helper.Wpf.Services;
using CoreLocalization = DM_Helper.Core.Services.Localization;

namespace DM_Helper.Wpf.Views;

/// <summary>
/// Main settings window - the counterpart of <c>MainWindowController.m</c> (1653 lines).
///
/// Editing rules that the macOS build earned the hard way, preserved here:
/// - A re-entrancy guard stops programmatic field updates from being written back.
/// - Language switching rebuilds every label from the model, so nothing is lost.
/// - The opener trigger key and its enable checkbox are two-way bound because several
///   releases on macOS shipped a bug where they could disagree.
/// - Debounced saving, so typing in a delay field does not hit the disk per keystroke.
/// </summary>
public partial class MainWindow : Window
{
    private readonly AppServices _app;
    private readonly CoreLocalization _l10n;

    private bool _updating;
    private string _profileId = "1";
    private readonly DispatcherTimer _saveTimer;

    public MainWindow()
    {
        InitializeComponent();

        _app = App.Services;
        _l10n = _app.L10n;

        _saveTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(400) };
        _saveTimer.Tick += (_, _) =>
        {
            _saveTimer.Stop();
            _app.Save(_profileId);
        };

        InputPoster.OwnWindowHandle = new System.Windows.Interop.WindowInteropHelper(this).Handle;
        ForegroundWindow.OwnWindow = InputPoster.OwnWindowHandle;

        BuildSkillRows();
        PopulateStaticChoices();
        WireTray();
        LoadProfile("1");

        _app.Initialize();

        _app.Engine.RunningChanged += _ => Dispatcher.Invoke(UpdateRunState);
        _app.Engine.OpenerStateChanged += _ => Dispatcher.Invoke(UpdateRunState);
        Closed += (_, _) =>
        {
            // Hiding the window must not stop the macro; the tray keeps it alive. But the
            // self-focus guard must be cleared, or input stays suppressed forever once the
            // settings window is closed.
            SaveNow();

            InputPoster.OwnWindowHandle = 0;
            ForegroundWindow.OwnWindow = 0;
        };

        ApplyLanguage();
        UpdateRunState();
    }

    // =====================================================================
    // Static content
    // =====================================================================

    private void PopulateStaticChoices()
    {
        PresetCombo.ItemsSource = KeyConfig.PresetNames.Select((p, i) => new
        {
            Kind = (KeyConfig.PresetKind)i,
            Label = _l10n.PresetName(p.Ko),
        }).ToArray();
        PresetCombo.DisplayMemberPath = "Label";
        PresetCombo.SelectedIndex = -1;

        LangCombo.ItemsSource = new[]
        {
            new { Mode = LanguageMode.Auto, Label = "🌐 Auto" },
            new { Mode = LanguageMode.Korean, Label = "🌐 KO" },
            new { Mode = LanguageMode.English, Label = "🌐 EN" },
        };
        LangCombo.DisplayMemberPath = "Label";
        LangCombo.SelectedValuePath = "Mode";
        LangCombo.SelectedValue = _l10n.Mode;

        ResolutionCombo.ItemsSource = DeadzoneFilterOptions.Options.Select(o => o.Label).ToArray();
    }

    /// <summary>Skill slot rows, kept as a typed list because Children is a UIElementCollection.</summary>
    private readonly List<SkillRowControl> _skillRows = new();

    private void BuildSkillRows()
    {
        for (var i = 0; i < 8; i++)
        {
            var row = new SkillRowControl { Slot = i + 1 };
            row.Changed += (_, _) => OnFieldEdited(this, new RoutedEventArgs());
            _skillRows.Add(row);
            SkillRowsPanel.Children.Add(row);
        }
    }

    private void WireTray()
    {
        var tray = _app.Tray;

        tray.ToggleRequested += () => Dispatcher.Invoke(() =>
        {
            _app.Engine.Toggle();
            UpdateRunState();
        });

        tray.OpenerRequested += () => Dispatcher.Invoke(() =>
        {
            _app.Engine.TriggerOpener();
            UpdateRunState();
        });

        tray.SettingsRequested += () => Dispatcher.Invoke(() =>
        {
            Show();
            WindowState = WindowState.Normal;
            Activate();
        });

        tray.PresetHubRequested += () => Dispatcher.Invoke(() => new PresetShareWindow().ShowDialog());
        tray.GuideRequested += () => Dispatcher.Invoke(() => new HelpWindow().Show());
        tray.QuitRequested += () => Dispatcher.Invoke(() => OnQuitRequested());

        // The tray outlives this window, so it must stop dispatching into a closed view.
        // Without this, quitting after closing the settings window would either throw or
        // silently do nothing depending on when the user clicked.
        Closed += (_, _) => tray.ClearHandlers();
    }

    private void OnQuitRequested()
    {
        // Flush the profile first: the engine keeps running after this window closes, so
        // an unsaved edit would otherwise be lost.
        SaveNow();
        Application.Current.Shutdown();
    }

    /// <summary>
    /// Pushes the UI into the engine and writes the profile, cancelling any pending
    /// debounced save so it cannot fire again against a stale state.
    /// </summary>
    private void SaveNow()
    {
        if (!_updating) CollectIntoEngine();

        _saveTimer.Stop();
        _app.Save(_profileId);
    }

    // =====================================================================
    // Profile load / save
    // =====================================================================

    private void LoadProfile(string profileId)
    {
        _profileId = profileId;

        _updating = true;
        try
        {
            var config = _app.Configs.Load(profileId);
            _app.Engine.Config = config;

            MemoBox.Text = config.Memo;
            SetRadio(profileId);

            InventoryKeyBox.InputKey = config.InventoryKey;
            SkillsKeyBox.InputKey = config.SkillsMenuKey;
            FollowerKeyBox.InputKey = config.FollowerKey;
            MapKeyBox.InputKey = config.MapKey;
            WorldMapKeyBox.InputKey = config.WorldMapKey;
            PortalKeyBox.InputKey = config.PortalKey;
            ChatKeyBox.InputKey = config.ChatKey;
            WhisperKeyBox.InputKey = config.WhisperKey;

            MainOpenerKeyBox.InputKey = config.OpenerTriggerKey;
            MainOpenerCheck.IsChecked = config.OpenerEnabled;

            OpenerTriggerKeyBox.InputKey = config.OpenerTriggerKey;
            OpenerCheck.IsChecked = config.OpenerEnabled;

            for (var i = 0; i < 8; i++)
            {
                _skillRows[i].Load(
                    config.SkillKey(i), config.SkillDelay(i),
                    config.SkillCheck(i), config.SkillHold(i));
            }

            Step0.Load(config.OpenerStepAt(0));
            Step1.Load(config.OpenerStepAt(1));
            Step2.Load(config.OpenerStepAt(2));
            Step3.Load(config.OpenerStepAt(3));
            Step4.Load(config.OpenerStepAt(4));

            ComboCheck.IsChecked = config.ComboEnabled;
            ComboGenKeyBox.InputKey = config.ComboGeneratorKey;
            ComboGenCountBox.Text = config.ComboGeneratorCount.ToString();
            ComboSpendKeyBox.InputKey = config.ComboSpenderKey;
            ComboSpendCountBox.Text = config.ComboSpenderCount.ToString();
            ComboIntervalBox.Text = config.ComboInterval.ToString();

            Single0.Load(config.SingleRepeatToggle(0), config.SingleRepeatAction(0),
                config.SingleRepeatDelay(0), true, "");
            Single1.Load(config.SingleRepeatToggle(1), config.SingleRepeatAction(1),
                config.SingleRepeatDelay(1), true, "");
            Single2.Load(config.SingleRepeatToggle(2), config.SingleRepeatAction(2),
                config.SingleRepeatDelay(2), true, "");

            SpecialKeyBox0.InputKey = config.SpecialKey(0);
            SpecialKeyBox1.InputKey = config.SpecialKey(1);
            SpecialKeyBox2.InputKey = config.SpecialKey(2);
            SpecialCooldown0.IsChecked = config.SpecialKeyCooldown(0);
            SpecialCooldown1.IsChecked = config.SpecialKeyCooldown(1);
            SpecialCooldown2.IsChecked = config.SpecialKeyCooldown(2);

            QuestKeyBox.InputKey = config.QuestKey;
            SpeedModKeyBox.InputKey = config.SpeedModKey;
            SpeedModToggleCheck.IsChecked = config.SpeedModToggleMode;
            SpeedModOffsetBox.Text = config.SpeedModOffset.ToString();

            AntiDisturbanceCheck.IsChecked = config.AntiDisturbanceEnabled;
            SoundFeedbackCheck.IsChecked = config.SoundFeedbackEnabled;
            ResolutionCombo.SelectedItem = config.SelectedResolution;
        }
        finally
        {
            _updating = false;
        }
    }

    private void SetRadio(string profileId)
    {
        var target = profileId switch
        {
            "2" => Profile2,
            "3" => Profile3,
            "4" => Profile4,
            "5" => Profile5,
            _ => Profile1,
        };

        target.IsChecked = true;
    }

    private void CollectIntoEngine()
    {
        var config = _app.Engine.Config;

        config.Memo = MemoBox.Text ?? "";

        config.InventoryKey = InventoryKeyBox.InputKey;
        config.SkillsMenuKey = SkillsKeyBox.InputKey;
        config.FollowerKey = FollowerKeyBox.InputKey;
        config.MapKey = MapKeyBox.InputKey;
        config.WorldMapKey = WorldMapKeyBox.InputKey;
        config.PortalKey = PortalKeyBox.InputKey;
        config.ChatKey = ChatKeyBox.InputKey;
        config.WhisperKey = WhisperKeyBox.InputKey;

        // The opener trigger key lives in two places in the UI; keep them in lockstep so
        // the user can never see them disagree.
        var openerKey = MainOpenerKeyBox.InputKey;
        MainOpenerKeyBox.InputKey = openerKey;
        OpenerTriggerKeyBox.InputKey = openerKey;

        var openerEnabled = MainOpenerCheck.IsChecked == true;
        MainOpenerCheck.IsChecked = openerEnabled;
        OpenerCheck.IsChecked = openerEnabled;
        config.OpenerEnabled = openerEnabled;
        config.OpenerTriggerKey = openerKey;

        for (var i = 0; i < 8; i++)
        {
            var (key, delay, check, hold) = _skillRows[i].Save();
            config.SkillKeys[i] = key;
            config.SkillDelays[i] = delay;
            config.SkillChecks[i] = check;
            config.SkillHolds[i] = hold;
        }

        config.OpenerSteps[0] = Step0.Save();
        config.OpenerSteps[1] = Step1.Save();
        config.OpenerSteps[2] = Step2.Save();
        config.OpenerSteps[3] = Step3.Save();
        config.OpenerSteps[4] = Step4.Save();

        config.ComboEnabled = ComboCheck.IsChecked == true;
        config.ComboGeneratorKey = ComboGenKeyBox.InputKey;
        config.ComboGeneratorCount = ReadInt(ComboGenCountBox.Text, 3);
        config.ComboSpenderKey = ComboSpendKeyBox.InputKey;
        config.ComboSpenderCount = ReadInt(ComboSpendCountBox.Text, 1);
        config.ComboInterval = ReadInt(ComboIntervalBox.Text, 150);

        var s0 = Single0.Save();
        config.SingleRepeatToggles[0] = s0.Toggle;
        config.SingleRepeatActions[0] = s0.Action;
        config.SingleRepeatDelays[0] = s0.Delay;

        var s1 = Single1.Save();
        config.SingleRepeatToggles[1] = s1.Toggle;
        config.SingleRepeatActions[1] = s1.Action;
        config.SingleRepeatDelays[1] = s1.Delay;

        var s2 = Single2.Save();
        config.SingleRepeatToggles[2] = s2.Toggle;
        config.SingleRepeatActions[2] = s2.Action;
        config.SingleRepeatDelays[2] = s2.Delay;

        config.SpecialKeys[0] = SpecialKeyBox0.InputKey;
        config.SpecialKeys[1] = SpecialKeyBox1.InputKey;
        config.SpecialKeys[2] = SpecialKeyBox2.InputKey;
        config.SpecialKeyCooldowns[0] = SpecialCooldown0.IsChecked == true;
        config.SpecialKeyCooldowns[1] = SpecialCooldown1.IsChecked == true;
        config.SpecialKeyCooldowns[2] = SpecialCooldown2.IsChecked == true;

        config.QuestKey = QuestKeyBox.InputKey;
        config.SpeedModKey = SpeedModKeyBox.InputKey;
        config.SpeedModToggleMode = SpeedModToggleCheck.IsChecked == true;
        config.SpeedModOffset = ReadInt(SpeedModOffsetBox.Text, 0);

        config.AntiDisturbanceEnabled = AntiDisturbanceCheck.IsChecked == true;
        config.SoundFeedbackEnabled = SoundFeedbackCheck.IsChecked == true;
        config.SelectedResolution = ResolutionCombo.SelectedItem as string ?? DeadzoneFilterOptions.AutoDetect;

        config.Sanitize();
    }

    private static int ReadInt(string? text, int fallback) =>
        int.TryParse(text, NumberStyles.Integer, CultureInfo.InvariantCulture, out var v) ? v : fallback;

    // =====================================================================
    // Event handlers
    // =====================================================================

    private void OnFieldEdited(object sender, RoutedEventArgs e)
    {
        if (_updating) return;

        CollectIntoEngine();

        _saveTimer.Stop();
        _saveTimer.Start();

        UpdateFooter();
    }

    private void OnKeyCaptured(object? sender, InputKey key)
    {
        if (_updating || sender is not FrameworkElement) return;

        CollectIntoEngine();

        _saveTimer.Stop();
        _saveTimer.Start();
    }

    private void OnProfileChanged(object sender, RoutedEventArgs e)
    {
        if (_updating || sender is not RadioButton { IsChecked: true } radio) return;

        if (radio.Tag is not string profileId) return;

        CollectIntoEngine();
        _app.Save(_profileId);

        LoadProfile(profileId);
        UpdateFooter();
    }

    private void OnPresetSelected(object sender, SelectionChangedEventArgs e)
    {
        if (_updating || PresetCombo.SelectedValue is not KeyConfig.PresetKind kind) return;

        var result = MessageBox.Show(
            $"{PresetCombo.Text} 프리셋을 적용하면 현재 프로필 설정이 교체됩니다. 계속할까요?",
            "프리셋 적용", MessageBoxButton.OKCancel, MessageBoxImage.Question);

        if (result != MessageBoxResult.OK)
        {
            _updating = true;
            PresetCombo.SelectedIndex = -1;
            _updating = false;
            return;
        }

        CollectIntoEngine();

        var preset = KeyConfig.ForPreset(kind);

        // Skill rows and opener steps need refreshing from the new preset.
        _updating = true;
        try
        {
            MemoBox.Text = preset.Memo;
            for (var i = 0; i < 8; i++)
            {
                _skillRows[i].Load(
                    preset.SkillKey(i), preset.SkillDelay(i),
                    preset.SkillCheck(i), preset.SkillHold(i));
            }

            for (var i = 0; i < 5; i++) GetStepRow(i).Load(preset.OpenerStepAt(i));

            MainOpenerKeyBox.InputKey = preset.OpenerTriggerKey;
            OpenerTriggerKeyBox.InputKey = preset.OpenerTriggerKey;
            MainOpenerCheck.IsChecked = preset.OpenerEnabled;
            OpenerCheck.IsChecked = preset.OpenerEnabled;

            ComboCheck.IsChecked = preset.ComboEnabled;
            ComboGenKeyBox.InputKey = preset.ComboGeneratorKey;
            ComboGenCountBox.Text = preset.ComboGeneratorCount.ToString();
            ComboSpendKeyBox.InputKey = preset.ComboSpenderKey;
            ComboSpendCountBox.Text = preset.ComboSpenderCount.ToString();
            ComboIntervalBox.Text = preset.ComboInterval.ToString();
        }
        finally
        {
            _updating = false;
        }

        OnFieldEdited(this, new RoutedEventArgs());
    }

    private void OnLangChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_updating || LangCombo.SelectedValue is not LanguageMode mode) return;

        CollectIntoEngine();
        _l10n.Mode = mode;
    }

    private void OnRunClick(object sender, RoutedEventArgs e)
    {
        CollectIntoEngine();
        _app.Save(_profileId);

        _app.Engine.Toggle();
        UpdateRunState();
    }

    private void OnOpenerClick(object sender, RoutedEventArgs e)
    {
        CollectIntoEngine();
        _app.Save(_profileId);

        _app.Engine.TriggerOpener();
        UpdateRunState();
    }

    private void OnPresetHubClick(object sender, RoutedEventArgs e) =>
        new PresetShareWindow().ShowDialog();

    private void OnGuideClick(object sender, RoutedEventArgs e) => new HelpWindow().Show();

    private void OnCloseClick(object sender, RoutedEventArgs e)
    {
        CollectIntoEngine();
        _app.Save(_profileId);
        Hide();
    }

    private void OnResetClick(object sender, RoutedEventArgs e)
    {
        var result = MessageBox.Show(
            "현재 프로필을 기본 설정으로 초기화합니다. 계속할까요?",
            "기본값으로 초기화", MessageBoxButton.OKCancel, MessageBoxImage.Warning);

        if (result != MessageBoxResult.OK) return;

        _updating = true;
        try
        {
            var config = KeyConfig.DefaultConfig();
            _app.Engine.Config = config;
            _app.Save(_profileId);
        }
        finally
        {
            _updating = false;
        }

        LoadProfile(_profileId);
    }

    private void OnExportClick(object sender, RoutedEventArgs e)
    {
        CollectIntoEngine();

        var dialog = new SaveFileDialog
        {
            Filter = "DM_Helper 프로필 (*.dhp)|*.dhp|JSON 파일 (*.json)|*.json",
            FileName = $"dm_helper_profile_{_profileId}.dhp",
            DefaultExt = ".dhp",
        };

        if (dialog.ShowDialog(this) != true) return;

        if (_app.Configs.Export(_app.Engine.Config, dialog.FileName))
            MessageBox.Show("저장되었습니다.", "DM_Helper", MessageBoxButton.OK, MessageBoxImage.Information);
        else
            MessageBox.Show("저장에 실패했습니다.", "DM_Helper", MessageBoxButton.OK, MessageBoxImage.Error);
    }

    private void OnImportClick(object sender, RoutedEventArgs e)
    {
        var dialog = new OpenFileDialog
        {
            Filter = "DM_Helper 프로필 (*.dhp;*.json)|*.dhp;*.json|모든 파일 (*.*)|*.*",
        };

        if (dialog.ShowDialog(this) != true) return;

        var config = _app.Configs.Import(dialog.FileName);
        if (config is null)
        {
            MessageBox.Show("프로필을 읽을 수 없습니다.", "DM_Helper", MessageBoxButton.OK, MessageBoxImage.Error);
            return;
        }

        _updating = true;
        try
        {
            _app.Engine.Config = config;
            _app.Save(_profileId);
        }
        finally
        {
            _updating = false;
        }

        LoadProfile(_profileId);
    }

    // =====================================================================
    // Presentation
    // =====================================================================

    private OpenerStepRow GetStepRow(int index0) => index0 switch
    {
        0 => Step0,
        1 => Step1,
        2 => Step2,
        3 => Step3,
        _ => Step4,
    };

    private void UpdateRunState()
    {
        var engine = _app.Engine;

        RunButton.Content = engine.IsRunning ? _l10n.T("engine_stop") : _l10n.T("engine_start");

        StatusLabel.Text = engine.IsOpenerRunning
            ? _l10n.T("status_opener")
            : engine.IsRunning ? _l10n.T("status_running") : _l10n.T("status_stopped");

        StatusLabel.Foreground = engine.IsRunning
            ? (System.Windows.Media.Brush)FindResource("RunningBrush")
            : (System.Windows.Media.Brush)FindResource("StoppedBrush");

        _app.Tray.UpdateState(engine.IsRunning, engine.IsOpenerRunning);

        if (!engine.IsRunning)
            HintLabel.Text = _l10n.T("hint_stopped");
        else if (engine.IsOpenerRunning)
            HintLabel.Text = _l10n.T("hint_opener");
        else
            HintLabel.Text = _l10n.T("hint_running");

        UpdateFooter();
    }

    private void UpdateFooter()
    {
        var config = _app.Engine.Config;

        var bound = Enumerable.Range(0, 8).Count(i => !config.SkillKey(i).IsEmpty);
        var mode = config.SpeedModToggleMode ? _l10n.T("speed_toggle") : _l10n.T("speed_hold");

        FooterLabel.Text = _l10n.Mode switch
        {
            LanguageMode.English =>
                $"Profile {_profileId} · {bound}/8 skills bound · Speed: {mode}",
            _ =>
                $"프로필 {_profileId} · 기술 {bound}/8개 바인딩 · 시간조절: {mode}",
        };
    }

    /// <summary>
    /// Rebuilds every label from the localization table. All binding values live in the
    /// model, so switching language cannot lose an edit.
    /// </summary>
    private void ApplyLanguage()
    {
        var t = _l10n.T;

        ProfileLabel.Text = t("profile_label");
        RunButton.Content = _app.Engine.IsRunning ? t("engine_stop") : t("engine_start");
        OpenerButton.Content = t("opener_btn");
        OpenerTestButton.Content = t("btn_opener_test");
        MemoLabel.Text = t("memo_label");
        MemoBox.ToolTip = t("memo_placeholder");

        TabHelper.Header = t("tab_helper");
        TabRotation.Header = t("tab_rotation");
        TabFeatures.Header = t("tab_features");

        BoxStartStop.Header = t("box_start_stop");
        LblStartKey.Text = t("label_start_key");
        LblStopKey.Text = t("label_stop_key");
        LblOpenerKey.Text = t("label_opener_key");
        MainOpenerCheck.Content = t("btn_opener_enable");
        StartStopHint.Text = t("hint_start_stop");

        BoxInGame.Header = t("box_ingame");
        LblInventory.Text = t("label_inventory");
        LblSkills.Text = t("label_skills");
        LblFollower.Text = t("label_follower");
        LblMap.Text = t("label_map");
        LblWorldMap.Text = t("label_world_map");
        LblPortal.Text = t("label_portal");
        LblChat.Text = t("label_chat");
        LblWhisper.Text = t("label_whisper");

        BoxSkills.Header = t("box_skills");

        BoxOpener.Header = t("box_opener");
        OpenerCheck.Content = t("btn_opener_enable");
        LblOpenerTrigger.Text = t("label_opener_trigger");

        BoxCombo.Header = t("box_combo");
        ComboCheck.Content = t("btn_combo_enable");
        LblComboGen.Text = t("label_combo_gen");
        LblComboSpend.Text = t("label_combo_spend");
        LblComboInterval.Text = t("label_combo_interval");
        ComboExample.Text = _l10n.IsKorean
            ? "예: 생성기 3회 ↔ 소모기 1회 (도적 3콤보)"
            : "e.g. generator x3 <-> spender x1 (Rogue 3-combo)";

        BoxSingleRepeat.Header = t("box_single_repeat");
        BoxSpecial.Header = t("box_special");
        LblQuestKey.Text = t("label_quest_key");
        QuestHint.Text = t("hint_quest");
        LblSpeedModKey.Text = t("label_speed_key");
        SpeedModToggleCheck.Content = t("label_speed_toggle");
        LblSpeedOffset.Text = t("label_speed_offset");
        SpeedHint.Text = t("hint_speed");

        BoxOptions.Header = t("box_options");
        AntiDisturbanceCheck.Content = t("label_anti_disturbance");
        SoundFeedbackCheck.Content = t("label_sound");
        LblResolution.Text = t("label_resolution");
        DeadzoneHint.Text = t("hint_deadzone");

        _updating = true;
        try
        {
            PresetCombo.ItemsSource = KeyConfig.PresetNames.Select((p, i) => new
            {
                Kind = (KeyConfig.PresetKind)i,
                Label = _l10n.PresetName(p.Ko),
            }).ToArray();
            PresetCombo.DisplayMemberPath = "Label";
            PresetCombo.SelectedIndex = -1;

            LangCombo.SelectedValue = _l10n.Mode;
        }
        finally
        {
            _updating = false;
        }

        UpdateRunState();
    }
}
