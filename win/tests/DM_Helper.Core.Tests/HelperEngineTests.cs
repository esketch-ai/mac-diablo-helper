using DM_Helper.Core.Engine;
using DM_Helper.Core.Interop;
using DM_Helper.Core.Models;

namespace DM_Helper.Core.Tests;

/// <summary>
/// Drives <see cref="HelperEngine"/> through a recording sink so the whole state machine
/// can be verified without injecting real input.
/// </summary>
public sealed class RecordingSink : IInputSink
{
    private readonly List<string> _log = new();
    private readonly object _gate = new();

    public IReadOnlyList<string> Log
    {
        get
        {
            lock (_gate) return _log.ToArray();
        }
    }

    public void Clear()
    {
        lock (_gate) _log.Clear();
    }

    public int CountOf(string entry)
    {
        lock (_gate) return _log.Count(l => l == entry);
    }

    public bool Contains(string entry)
    {
        lock (_gate) return _log.Contains(entry);
    }

    public void Send(InputKey key) => Record($"send:{key.DisplayString}");

    public void KeyDown(InputKey key) => Record($"down:{key.DisplayString}");

    public void KeyUp(InputKey key) => Record($"up:{key.DisplayString}");

    private void Record(string entry)
    {
        lock (_gate) _log.Add(entry);
    }
}

public class HelperEngineTests
{
    private static readonly InputKey Bracket = InputKey.FromKey(Vk.Oem4);
    private static readonly InputKey One = InputKey.FromKey(Vk.D1);
    private static readonly InputKey RightMouse = InputKey.FromMouse(MouseButton.Right);

    private static (HelperEngine Engine, RecordingSink Sink) Build(KeyConfig config)
    {
        var engine = new HelperEngine { Config = config };
        var sink = new RecordingSink();
        engine.Sink = sink;
        return (engine, sink);
    }

    private static KeyConfig MinimalConfig()
    {
        var c = KeyConfig.DefaultConfig();
        c.StartInputKey = InputKey.FromKey(Vk.F9);
        c.StopInputKey = InputKey.FromKey(Vk.F10);
        c.OpenerEnabled = false;
        for (var i = 0; i < 8; i++)
        {
            c.SkillChecks[i] = false;
            c.SkillHolds[i] = false;
            c.SkillDelays[i] = 0;
            c.SkillKeys[i] = InputKey.Empty;
        }
        return c;
    }

    [Fact]
    public void StartStopKeyStartsAndStopsTheEngine()
    {
        var (engine, _) = Build(MinimalConfig());
        using var _e = engine;

        Assert.False(engine.IsRunning);

        engine.HandleInput(new InputEvent(InputKey.FromKey(Vk.F9), true, false));
        Assert.True(engine.IsRunning);

        engine.HandleInput(new InputEvent(InputKey.FromKey(Vk.F10), true, false));
        Assert.False(engine.IsRunning);
    }

    [Fact]
    public void SharedStartStopKeyTogglesWithDebounce()
    {
        var config = MinimalConfig();
        config.StopInputKey = config.StartInputKey; // same key -> toggle
        var (engine, _) = Build(config);
        using var _e = engine;

        engine.HandleInput(new InputEvent(config.StartInputKey, true, false));
        Assert.True(engine.IsRunning);

        // An immediate second press must be swallowed by the 250ms debounce.
        engine.HandleInput(new InputEvent(config.StartInputKey, true, false));
        Assert.True(engine.IsRunning);

        Thread.Sleep(300);
        engine.HandleInput(new InputEvent(config.StartInputKey, true, false));
        Assert.False(engine.IsRunning);
    }

    [Fact]
    public void AutorepeatCannotStartTheEngineTwice()
    {
        var (engine, _) = Build(MinimalConfig());
        using var _e = engine;

        engine.HandleInput(new InputEvent(InputKey.FromKey(Vk.F9), true, false));
        engine.HandleInput(new InputEvent(InputKey.FromKey(Vk.F9), true, true)); // repeat
        engine.HandleInput(new InputEvent(InputKey.FromKey(Vk.F9), false, false));

        Assert.True(engine.IsRunning);
    }

    [Fact]
    public void SkillSlotFiresOnItsInterval()
    {
        var config = MinimalConfig();
        config.SkillKeys[0] = One;
        config.SkillDelays[0] = 40;
        config.SkillChecks[0] = true;

        var (engine, sink) = Build(config);
        using var _e = engine;

        engine.Start();
        Thread.Sleep(400);
        engine.Stop();

        Assert.True(sink.CountOf("send:1") >= 5,
            $"expected repeated '1' presses, log: {string.Join(",", sink.Log.Distinct())}");
    }

    /// <summary>
    /// <c>skillCheck</c> is the "pause while a special key is held" link, not an
    /// enable/disable flag - an unlinked slot still fires on its own interval. This matches
    /// <c>fireSkillSlotLocked</c> in the macOS build.
    /// </summary>
    [Fact]
    public void UnlinkedSkillSlotStillFiresOnItsInterval()
    {
        var config = MinimalConfig();
        config.SkillKeys[0] = One;
        config.SkillDelays[0] = 30;
        config.SkillChecks[0] = false; // not linked to any special key

        var (engine, sink) = Build(config);
        using var _e = engine;

        engine.Start();
        Thread.Sleep(250);
        engine.Stop();

        Assert.True(sink.CountOf("send:1") >= 4,
            $"unlinked slot should keep firing, saw {sink.CountOf("send:1")}");
    }

    /// <summary>An empty key is the only way to stop a slot firing.</summary>
    [Fact]
    public void SlotWithNoKeyNeverFires()
    {
        var config = MinimalConfig();
        config.SkillKeys[0] = InputKey.Empty;
        config.SkillDelays[0] = 30;
        config.SkillChecks[0] = true;

        var (engine, sink) = Build(config);
        using var _e = engine;

        engine.Start();
        Thread.Sleep(200);
        engine.Stop();

        Assert.Equal(0, sink.CountOf("send:"));
    }

    [Fact]
    public void StoppingReleasesHeldChannelSkills()
    {
        var config = MinimalConfig();
        config.SkillKeys[0] = RightMouse;
        config.SkillHolds[0] = true;
        config.SkillChecks[0] = true;
        config.SkillDelays[0] = 0;

        var (engine, sink) = Build(config);
        using var _e = engine;

        engine.Start();
        Thread.Sleep(80);

        Assert.Equal(1, sink.CountOf("down:Mouse Right"));

        engine.Stop();
        Thread.Sleep(80);

        Assert.Equal(1, sink.CountOf("up:Mouse Right"));
    }

    [Fact]
    public void OpenerSequenceRunsThenFallsIntoTheMainLoop()
    {
        var config = MinimalConfig();
        config.StartInputKey = InputKey.FromKey(Vk.F9);
        config.OpenerEnabled = true;
        config.OpenerSteps[0] = OpenerStep.Create(One, 20, 1, "step1");
        config.OpenerSteps[1] = OpenerStep.Create(InputKey.FromKey(Vk.D2), 20, 2, "step2");
        config.SkillKeys[0] = InputKey.FromKey(Vk.D3);
        config.SkillDelays[0] = 40;
        config.SkillChecks[0] = true;

        var (engine, sink) = Build(config);
        using var _e = engine;

        engine.Start();
        Assert.True(engine.IsOpenerRunning);

        Thread.Sleep(500);

        Assert.False(engine.IsOpenerRunning);
        Assert.Equal(1, sink.CountOf("send:1"));      // opener step 1, once
        Assert.Equal(2, sink.CountOf("send:2"));      // opener step 2, repeated twice
        Assert.True(sink.CountOf("send:3") >= 2, "main loop should take over after the opener");
    }

    [Fact]
    public void StoppingMidOpenerCancelsTheRemainingSteps()
    {
        var config = MinimalConfig();
        config.OpenerEnabled = true;
        config.OpenerSteps[0] = OpenerStep.Create(One, 200, 1, "step1");
        config.OpenerSteps[1] = OpenerStep.Create(InputKey.FromKey(Vk.D2), 200, 1, "step2");

        var (engine, sink) = Build(config);
        using var _e = engine;

        engine.Start();
        Thread.Sleep(50);
        engine.Stop();
        sink.Clear();

        Thread.Sleep(500);
        Assert.Equal(0, sink.CountOf("send:2"));
    }

    [Fact]
    public void QuestKeySuppressesEverySkill()
    {
        var config = MinimalConfig();
        config.QuestKey = InputKey.FromKey(Vk.F8);
        config.SkillKeys[0] = One;
        config.SkillDelays[0] = 25;
        config.SkillChecks[0] = true;

        var (engine, sink) = Build(config);
        using var _e = engine;

        engine.Start();
        engine.HandleInput(new InputEvent(InputKey.FromKey(Vk.F8), true, false));
        Thread.Sleep(250);
        Assert.Equal(0, sink.CountOf("send:1"));

        engine.HandleInput(new InputEvent(InputKey.FromKey(Vk.F8), false, false));
        Thread.Sleep(250);
        Assert.True(sink.CountOf("send:1") > 0);
    }

    [Fact]
    public void SpecialKeySuppressesOnlyCheckedSkills()
    {
        var config = MinimalConfig();
        config.SpecialKeys[0] = InputKey.FromKey(Vk.F7);
        config.SkillKeys[0] = One;
        config.SkillDelays[0] = 25;
        config.SkillChecks[0] = true;

        config.SkillKeys[1] = InputKey.FromKey(Vk.D2);
        config.SkillDelays[1] = 25;
        config.SkillChecks[1] = false;

        var (engine, sink) = Build(config);
        using var _e = engine;

        engine.Start();
        engine.HandleInput(new InputEvent(InputKey.FromKey(Vk.F7), true, false));
        Thread.Sleep(250);

        Assert.Equal(0, sink.CountOf("send:1"));
        Assert.True(sink.CountOf("send:2") > 0, "unchecked skill must keep firing");
    }

    [Fact]
    public void ReleasingSpecialKeyWithoutCooldownWaitFiresImmediately()
    {
        var config = MinimalConfig();
        config.SpecialKeys[0] = InputKey.FromKey(Vk.F7);
        config.SpecialKeyCooldowns[0] = false;
        config.SkillKeys[0] = One;
        config.SkillDelays[0] = 5000; // effectively off while the special key is held
        config.SkillChecks[0] = true;

        var (engine, sink) = Build(config);
        using var _e = engine;

        engine.Start();
        engine.HandleInput(new InputEvent(InputKey.FromKey(Vk.F7), true, false));
        sink.Clear();

        engine.HandleInput(new InputEvent(InputKey.FromKey(Vk.F7), false, false));
        Thread.Sleep(60);

        Assert.Equal(1, sink.CountOf("send:1"));
    }

    [Fact]
    public void SingleRepeatKeyWorksWhileTheMainLoopIsStopped()
    {
        var config = MinimalConfig();
        config.SingleRepeatToggles[0] = InputKey.FromKey(Vk.Oem3);
        config.SingleRepeatActions[0] = InputKey.FromMouse(MouseButton.Left);
        config.SingleRepeatDelays[0] = 25;

        var (engine, sink) = Build(config);
        using var _e = engine;

        Assert.False(engine.IsRunning);

        engine.HandleInput(new InputEvent(InputKey.FromKey(Vk.Oem3), true, false));
        Thread.Sleep(220);

        Assert.True(sink.CountOf("send:Mouse Left") >= 4);

        engine.HandleInput(new InputEvent(InputKey.FromKey(Vk.Oem3), false, false));
        sink.Clear();
        Thread.Sleep(150);
        Assert.Equal(0, sink.CountOf("send:Mouse Left"));
    }

    [Fact]
    public void WheelToggleFlipsInsteadOfLatching()
    {
        var config = MinimalConfig();
        config.SingleRepeatToggles[0] = InputKey.FromWheel(WheelDirection.Up);
        config.SingleRepeatActions[0] = InputKey.FromMouse(MouseButton.Left);
        config.SingleRepeatDelays[0] = 25;

        var (engine, sink) = Build(config);
        using var _e = engine;

        // A wheel has no key-up, so each press toggles.
        engine.HandleInput(new InputEvent(InputKey.FromWheel(WheelDirection.Up), true, false));
        Thread.Sleep(150);
        Assert.True(sink.CountOf("send:Mouse Left") > 0);

        engine.HandleInput(new InputEvent(InputKey.FromWheel(WheelDirection.Up), true, false));
        sink.Clear();
        Thread.Sleep(150);
        Assert.Equal(0, sink.CountOf("send:Mouse Left"));
    }

    [Fact]
    public void ComboCycleAlternatesGeneratorAndSpender()
    {
        var config = MinimalConfig();
        config.ComboEnabled = true;
        config.ComboGeneratorKey = One;
        config.ComboGeneratorCount = 3;
        config.ComboSpenderKey = RightMouse;
        config.ComboSpenderCount = 1;
        config.ComboInterval = 30;

        var (engine, sink) = Build(config);
        using var _e = engine;

        engine.Start();
        Thread.Sleep(700);
        engine.Stop();

        var gens = sink.CountOf("send:1");
        var spenders = sink.CountOf("send:Mouse Right");

        Assert.True(gens > 0 && spenders > 0);
        // 3 generator presses per spender press.
        Assert.InRange(spenders, gens / 4, gens / 2);
    }

    [Fact]
    public void AntiDisturbanceBlocksClicksOverTheActionBar()
    {
        var config = MinimalConfig();
        config.SkillKeys[0] = InputKey.FromMouse(MouseButton.Left);
        config.SkillDelays[0] = 25;
        config.SkillChecks[0] = true;
        config.AntiDisturbanceEnabled = true;
        config.SelectedResolution = "1920 x 1080 (FHD)";

        // Cursor parked in the middle of the action bar.
        Services.DeadzoneFilter.CursorOverride = (960, 950);

        try
        {
            var (engine, sink) = Build(config);
            using var _e = engine;

            engine.Start();
            Thread.Sleep(250);
            engine.Stop();

            Assert.Equal(0, sink.CountOf("send:Mouse Left"));
        }
        finally
        {
            Services.DeadzoneFilter.CursorOverride = null;
        }
    }

    [Fact]
    public void RunningChangedEventFiresOnStartAndStop()
    {
        var (engine, _) = Build(MinimalConfig());
        using var _e = engine;

        var states = new List<bool>();
        engine.RunningChanged += states.Add;

        engine.Start();
        engine.Stop();

        Assert.Equal(new[] { true, false }, states);
    }

    [Fact]
    public void ReplacingTheConfigRestartsRunningTimers()
    {
        var config = MinimalConfig();
        config.SkillKeys[0] = One;
        config.SkillDelays[0] = 40;
        config.SkillChecks[0] = true;

        var (engine, sink) = Build(config);
        using var _e = engine;

        engine.Start();
        Thread.Sleep(120);

        var updated = MinimalConfig();
        updated.SkillKeys[0] = InputKey.FromKey(Vk.D2);
        updated.SkillDelays[0] = 40;
        updated.SkillChecks[0] = true;
        engine.Config = updated;

        sink.Clear();
        Thread.Sleep(200);
        engine.Stop();

        Assert.True(sink.CountOf("send:2") > 0);
        Assert.Equal(0, sink.CountOf("send:1"));
    }

    [Fact]
    public void DisposeIsSafeToCallTwice()
    {
        var engine = new HelperEngine { Config = MinimalConfig() };
        engine.Start();
        engine.Dispose();
        engine.Dispose();
    }
}
