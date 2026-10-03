using System.Windows;
using System.Windows.Controls;
using DM_Helper.Core.Services;

namespace DM_Helper.Wpf.Views;

/// <summary>
/// Built-in manual - the counterpart of the <c>NSAttributedString</c> HTML guide on macOS.
///
/// Rendered as a native WPF <see cref="TextBlock"/> rather than a WebView2 host: there is no
/// markup to interpret, so WebView2 would add a ~150MB runtime dependency for no benefit,
/// and a plain control always renders in light and dark mode.
/// </summary>
public partial class HelpWindow : Window
{
    private const int CategoryCount = 5;

    public HelpWindow()
    {
        InitializeComponent();

        LangCombo.ItemsSource = new[]
        {
            new { Mode = LanguageMode.Korean, Label = "한국어" },
            new { Mode = LanguageMode.English, Label = "English" },
        };
        LangCombo.DisplayMemberPath = "Label";
        LangCombo.SelectedValuePath = "Mode";
        LangCombo.SelectedValue = Localization.Instance.Mode;
        LangCombo.SelectionChanged += OnLangChanged;

        CategoryCombo.ItemsSource = Enumerable.Range(0, CategoryCount)
            .Select(i => new { Index = i, Label = CategoryLabel(i) })
            .ToArray();
        CategoryCombo.DisplayMemberPath = "Label";
        CategoryCombo.SelectedIndex = 0;
        CategoryCombo.SelectionChanged += OnCategoryChanged;

        Render();
    }

    private int _category;
    private bool _updating;

    private string CategoryLabel(int index)
    {
        var ko = Localization.Instance.IsKorean;
        return index switch
        {
            0 => ko ? "시작하기" : "Getting started",
            1 => ko ? "기술 슬롯 & 특수키" : "Skill slots & special keys",
            2 => ko ? "준비 시퀀스 & 콤보" : "Opener & combo",
            3 => ko ? "편의기능" : "Quality of life",
            _ => ko ? "문제 해결" : "Troubleshooting",
        };
    }

    private void OnCategoryChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_updating || CategoryCombo.SelectedValue is not int index) return;
        _category = index;
        Render();
    }

    private void OnLangChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_updating || LangCombo.SelectedValue is not LanguageMode mode) return;

        Localization.Instance.Mode = mode;
        _updating = true;
        try
        {
            CategoryCombo.ItemsSource = Enumerable.Range(0, CategoryCount)
                .Select(i => new { Index = i, Label = CategoryLabel(i) })
                .ToArray();
            CategoryCombo.DisplayMemberPath = "Label";
            CategoryCombo.SelectedIndex = _category;
        }
        finally
        {
            _updating = false;
        }

        Render();
    }

    private void OnCloseClick(object sender, RoutedEventArgs e) => Close();

    private void Render()
    {
        var ko = Localization.Instance.IsKorean;

        HeaderText.Text = ko ? "DM_Helper 사용 설명서" : "DM_Helper Manual";
        BodyText.Text = _category switch
        {
            0 => ko ? HelpText.QuickStartKo : HelpText.QuickStartEn,
            1 => ko ? HelpText.SkillsKo : HelpText.SkillsEn,
            2 => ko ? HelpText.OpenerKo : HelpText.OpenerEn,
            3 => ko ? HelpText.QoLKo : HelpText.QoLEn,
            _ => ko ? HelpText.TroubleshootingKo : HelpText.TroubleshootingEn,
        };
    }
}

/// <summary>
/// Guide copy, bilingual. Kept as plain strings rather than the macOS HTML so the window
/// inherits the live app theme with no web runtime involved.
/// </summary>
internal static class HelpText
{
    public const string QuickStartKo = """
        3분快速 시작

        1. 앱을 실행하면 UAC(관리자 권한) 확인 창이 뜹니다. 반드시 '예'를 누르세요.
           디아블로4가 관리자 권한으로 실행될 때 입력 주입이 차단되므로 필수입니다.

        2. 상단에서 프로필 1~5 중 하나를 고르고, '직업 프리셋 적용'에서 자신의 직업과
           같은 빌드를 선택합니다.

        3. 디아블로4를 창 활성화 상태로 만든 뒤 시작 키(기본은 '[')를 누릅니다.
           준비 시퀀스가 실행된 뒤 본 전투 루프로 자동 전환됩니다.

        다시 누르면 종료됩니다. 시작/종료 키를 동일하게 두면 토글로 동작합니다.

        ⚠ 창이 활성화된 상태에서는 매크로 키가 전송되지 않습니다.
        설정 창이 아니라 게임을 보고 있어야 입력이 들어갑니다.
        """;

    public const string QuickStartEn = """
        Quick start (3 minutes)

        1. Launching the app raises a UAC prompt. You must click 'Yes'.
           Input injection is blocked when Diablo 4 runs at a higher privilege level,
           so this is required rather than optional.

        2. Pick one of profiles 1-5, then choose your class from the preset dropdown.

        3. Bring Diablo 4 to the foreground and press the start key ('[' by default).
           The opener sequence runs, then the main combat loop takes over.

        Pressing it again stops the macro. Setting start and stop to the same key makes
        it a toggle.

        Note: no keys are sent while a DM_Helper window has focus. Make sure the game
        is the active window, not this app.
        """;

    public const string SkillsKo = """
        기술 슬롯 1~8

        각 슬롯에는 키, 시전 방식(연타/홀드), 주기(ms)를 지정합니다.
        마우스 휠과 좌/우클릭, 사이드 버튼(XButton 1/2)도 바인딩할 수 있습니다.

        연타(Spam): 주기마다 눌러 줍니다.
        홀드(Hold): 누르고 있는 상태를 유지합니다 (소용돌이 등 채널링 스킬용).
                    이 모드에서는 주기 입력이 적용되지 않습니다.

        슬롯 왼쪽의 V 체크는 '특수키 연동'입니다.
        꺼두면 그 슬롯은 특수키를 눌러도 멈추지 않습니다.

        특수키 (최대 3개)
        누르고 있는 동안 V가 체크된 슬롯만 일시정지합니다.
        '쿨타임 대기'를 켜면 뗄 때 해당 스킬의 대기시간을 충족한 뒤 발사합니다.
        끄면 즉시 1회 발사합니다.

        인게임 종료 키
        소지품(I), 지도(M), 차원문(T), 채팅(Enter) 같은 UI를 열면 헬퍼가 자동으로
        멈춥니다. 전투 중에는 방해가 되지 않도록 비워둔 것을 권장합니다.
        """;

    public const string SkillsEn = """
        Skill slots 1-8

        Each slot takes a key, a mode (Spam or Hold), and an interval in ms. The mouse
        wheel, left/right buttons and side buttons (XButton 1/2) can all be bound.

        Spam: pressed repeatedly on the interval.
        Hold: stays held down for channel skills such as Whirlwind. The interval field
              is not used in this mode.

        The V checkbox on a slot means 'link to special keys'. Leaving it off means that
        slot keeps firing even while a special key is held.

        Special keys (up to 3)
        Holding one pauses only the slots with V checked. With 'cooldown wait' enabled,
        the skill fires once its own delay has elapsed after you let go; with it disabled,
        it fires immediately, exactly once.

        In-game stop keys
        Opening inventory (I), map (M), portal (T) or chat (Enter) pauses the helper
        automatically. Leaving them unbound is recommended so nothing interrupts combat.
        """;

    public const string OpenerKo = """
        초기 준비 시퀀스 (Opener)

        최대 5단계로 구성됩니다. 각 단계는 키 / 대기시간(ms) / 반복 횟수 / 설명을 가집니다.
        예: 아보디안 소환 → 탈태 → 어둠의 감옥 → 인장 버프

        '준비 키'(기본 F1)를 누르면 전투 중에도 수동으로 실행할 수 있습니다.
        시작키를 누르면 준비 시퀀스가 자동 실행된 뒤 본 루프로 넘어갑니다.

        연계 콤보 사이클 (생성기 → 소모기)
        생성기를 N회 누른 뒤 소모기를 M회 누르는 교대 반복입니다.
        예: 도적 - 구멍 뚫기 3회 ↔ 회전 칼날 1회

        상태 표시는 상단 버튼과 트레이 아이콘에서 확인할 수 있습니다.
        준비 시퀀스가 실행 중이면 '⚡ 준비 중...'으로 표시됩니다.
        """;

    public const string OpenerEn = """
        Opener sequence

        Up to five stages, each with a key, delay (ms), repeat count and a note.
        Example: summon Avatars -> Metamorphosis -> Dark Prison -> Sigil.

        The trigger key (F1 by default) runs it manually mid-combat. Pressing the start
        key runs it first, then hands over to the main loop.

        Generator-to-spender combo
        Alternates N presses of the generator with M presses of the spender.
        Example: Rogue - 3x Barbage Arrow into 1x Whirlwind.

        Progress is visible on the top button and the tray icon; the opener shows as
        '⚡ 준비 중...'.
        """;

    public const string QoLKo = """
        단일반복키 (독립 반복)

        메인 헬퍼의 실행 여부와 무관하게 동작합니다.

        기본값 1: ` ( grave) 키를 누르고 있으면 좌클릭을 50ms 간격으로 연타
                   → 바닥 아이템 자동 줍기
        기본값 2: Tab 키를 누르고 있으면 우클릭을 60ms 간격으로 연타
                   → 카달라/상점 대량 겜블
        기본값 3: 비어 있음

        퀘스트키
        NPC 대화 중 누르고 있으면 모든 스킬이 일시정지합니다.

        시간조절키
        도관/쿨감 신단을 획득했을 때 누르면 전체 주기가 빨라지거나 느려집니다.
        '주기 보정(ms)'에 음수를 넣으면 빨라지고 양수를 넣으면 느려집니다.
        토글 모드를 켜면 누를 때마다 On/Off가 전환됩니다.

        방해금지 데드존
        커서가 화면 하단 스킬바나 우측 상단 미니맵 위에 있을 때 좌클릭 기술의 발송을
        막습니다. 실수로 지도를 열거나 스킬을 날리는 것을 방지합니다.

        다국어
        상단 언어 메뉴에서 KO / EN / Auto를 고를 수 있습니다.
        전환해도 편집 중인 키 매핑과 주기, 메모는 그대로 유지됩니다.
        """;

    public const string QoLEn = """
        Single-repeat keys (independent)

        These run regardless of whether the main loop is active.

        Default 1: hold ` (grave) to spam left click every 50ms - auto item pickup.
        Default 2: hold Tab to spam right click every 60ms - Kadala / gambling rerolls.
        Default 3: unbound.

        Quest key
        Holding it while talking to an NPC pauses every skill.

        Speed modifier
        Press it after picking up an Ashes-of-Oregon-type time gift to speed up or slow
        down the whole rotation. A negative offset speeds it up, a positive one slows it.
        In toggle mode each press flips between on and off.

        Anti-disturbance deadzone
        Suppresses a left-click skill when the cursor sits over the bottom action bar or
        the top-right minimap, so a misfire cannot open the map or spend a skill.

        Language
        Switch between KO / EN / Auto from the language menu. Key bindings, delays and
        notes are preserved across the switch.
        """;

    public const string TroubleshootingKo = """
        입력 전혀 들어가지 않을 때

        1. 관리자 권한으로 실행 중인지 확인하세요.
           창 제목이 '관리자: DM_Helper'로 표시되어야 합니다.
           게임(Task Manager 참조)이 관리자 권한이면 헬퍼도 관리자여야 합니다.

        2. 창이 아니라 게임이 활성화되어 있어야 합니다.

        3. 트레이 아이콘을 오른쪽 클릭하여 상태를 확인하세요.

        잘못된 키가 잡힐 때

        필드를 클릭하면 '키 입력 대기'가 표시됩니다. 이 상태에서 ESC 또는 Delete를
        누르면 비워집니다. 포커스가 다른 곳으로 빠져도 원래 값으로 되돌아갑니다.

        시작키가 여러 번 눌려 보이는 경우

        시작/종료 키가 같으면 토글입니다. 키 반복으로 연속 전환되지 않도록 250ms
        디바운드가 걸려 있습니다. 그래도 불안정하면 시작키와 종료키를 다르게 지정하세요.

        지터가 느껴질 때

        기본 주기는 120ms 이상을 권장합니다. 50ms처럼 아주 짧은 주기는 게임 프레임과
        겹쳐 uneven하게 느껴질 수 있습니다. 스파이크 도구(DM_Helper_Spike.exe)로 실제
        지터를 측정할 수 있습니다.

        프리셋 공유 시트가 비어 있을 때

        최초 1회 시트 조회에는 네트워크 연결이 필요합니다. 실패하면 기본 프리셋 목록이
        표시되며 이후 캐시된 결과를 사용합니다.
        """;

    public const string TroubleshootingEn = """
        No input at all

        1. Confirm the app is running elevated - the title bar should read
           'Administrator: DM_Helper'. If the game runs elevated (check Task Manager),
           the helper must too.

        2. The game must be the focused window, not this app.

        3. Right-click the tray icon to inspect the current state.

        A wrong key gets bound

        Click a field to see 'press a key'; while waiting, press ESC or Delete to clear
        it. Moving focus away without choosing restores the previous binding.

        The start key seems to toggle repeatedly

        When start and stop share a key it acts as a toggle, with a 250ms debounce so
        autorepeat cannot flap it. If it still misbehaves, assign different keys.

        Timing feels uneven

        Intervals of 120ms or more are recommended. Very short intervals such as 50ms
        can collide with the game's frame rate. Run DM_Helper_Spike.exe to measure the
        real jitter on your machine.

        The preset sheet looks empty

        The first fetch needs a network connection. After a failure the bundled presets
        are shown, and later runs use the cached results.
        """;
}
