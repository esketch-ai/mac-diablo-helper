using DM_Helper.Core.Interop;
using DM_Helper.Core.Models;
using DM_Helper.Core.Services;

namespace DM_Helper.Core.Engine;

public enum EngineState
{
    Stopped,
    Running,
    OpenerRunning,
}

/// <summary>
/// The macro engine - a direct port of <c>D3HelperEngine.m</c>.
///
/// Behaviour is preserved exactly, including the details that took several bug fixes on
/// macOS:
/// - 250ms debounce on the shared start/stop key so OS autorepeat cannot flap it.
/// - Single-repeat keys work whether or not the main loop is running.
/// - A mouse wheel toggle flips rather than latching, because a wheel has no key-up.
/// - Releasing a special key with "cooldown wait" unchecked fires once immediately and
///   pushes the timer out a full period, avoiding a double-shot burst.
/// - Hold-mode skills are released with an explicit key-up whenever a pause applies.
/// - Opener steps are gated by a generation counter so a stop mid-sequence cannot leave a
///   dangling continuation running.
/// </summary>
public sealed class HelperEngine : IDisposable
{
    private const int SkillSlotCount = 8;
    private const int SingleRepeatCount = 3;
    private const int SpecialKeyCount = 3;
    private const double ToggleDebounceMs = 250;

    private readonly PreciseTimer _timer = new();
    private readonly InputSender _sender = new();
    private readonly object _gate = new();

    private readonly int[] _skillHandles = new int[SkillSlotCount];
    private readonly bool[] _skillHeld = new bool[SkillSlotCount];
    private readonly long[] _lastFireTicks = new long[SkillSlotCount];

    private readonly int[] _singleHandles = new int[SingleRepeatCount];
    private readonly InputKey?[] _singleActiveKeys = new InputKey?[SingleRepeatCount];

    private readonly bool[] _specialActive = new bool[SpecialKeyCount];

    private long _openerGeneration;
    private int _comboPhase;
    private int _comboCount;
    private long _lastToggleMs;
    private long _lastSpeedToggleMs;

    private KeyConfig _config = new();

    public HelperEngine()
    {
        _timer = new PreciseTimer("DM_Helper.Engine");
        _sender.Start();
    }

    // =====================================================================
    // State
    // =====================================================================

    public EngineState State { get; private set; } = EngineState.Stopped;

    public bool IsRunning => State != EngineState.Stopped;

    public bool IsOpenerRunning => State == EngineState.OpenerRunning;

    /// <summary>KeyConfig currently driving the engine. Replacing it restarts the timers.</summary>
    public KeyConfig Config
    {
        get
        {
            lock (_gate) return _config;
        }
        set
        {
            lock (_gate)
            {
                _config = value;
                if (IsRunning && !IsOpenerRunning) RestartSkillTimers();
            }
        }
    }

    /// <summary>Raised on the scheduler thread whenever the run state changes.</summary>
    public event Action<bool>? RunningChanged;

    /// <summary>Raised when the opener phase starts or ends.</summary>
    public event Action<bool>? OpenerStateChanged;

    /// <summary>Optional sink used by tests instead of real injection.</summary>
    public IInputSink? Sink { get; set; }

    public void Start() => Run(() => StartLocked());

    public void Stop() => Run(() => StopLocked());

    public void Toggle() => Run(() =>
    {
        if (IsRunning) StopLocked();
        else StartLocked();
    });

    public void TriggerOpener() => Run(TriggerOpenerLocked);

    private void Run(Action action)
    {
        lock (_gate) action();
    }

    // =====================================================================
    // Start / stop
    // =====================================================================

    private void StartLocked()
    {
        if (IsRunning) return;

        State = EngineState.Running;
        var generation = ++_openerGeneration;

        RaiseRunningChanged(true);

        if (_config.OpenerEnabled) RunOpener(generation);
        else RestartSkillTimers();
    }

    private void StopLocked()
    {
        if (!IsRunning) return;

        _openerGeneration++;
        State = EngineState.Stopped;
        StopAllSkillTimers();

        RaiseRunningChanged(false);
    }

    private void RaiseRunningChanged(bool running)
    {
        try
        {
            RunningChanged?.Invoke(running);
        }
        catch
        {
            // A UI handler must not break the engine.
        }
    }

    private void RaiseOpenerChanged(bool running)
    {
        try
        {
            OpenerStateChanged?.Invoke(running);
        }
        catch
        {
        }
    }

    // =====================================================================
    // Opener sequence
    // =====================================================================

    private void RunOpener(long generation)
    {
        var steps = _config.OpenerSteps.Where(s => !s.IsEmpty).ToArray();
        if (steps.Length == 0)
        {
            RaiseOpenerChanged(false);
            RestartSkillTimers();
            return;
        }

        State = EngineState.OpenerRunning;
        RaiseOpenerChanged(true);

        RunOpenerStep(steps, 0, 0, generation);
    }

    private void RunOpenerStep(OpenerStep[] steps, int stepIndex, int repeatIndex, long generation)
    {
        if (!IsRunning || generation != _openerGeneration)
        {
            EndOpener();
            return;
        }

        if (stepIndex >= steps.Length)
        {
            EndOpener();
            if (IsRunning) RestartSkillTimers();
            return;
        }

        var step = steps[stepIndex];
        var total = Math.Max(step.RepeatCount, 1);
        var delay = Math.Max(step.DelayMs, 10);

        Post(step.Key);

        if (repeatIndex + 1 < total)
            Schedule(delay, () => RunOpenerStep(steps, stepIndex, repeatIndex + 1, generation));
        else
            Schedule(delay, () => RunOpenerStep(steps, stepIndex + 1, 0, generation));
    }

    private void EndOpener()
    {
        if (State == EngineState.OpenerRunning)
        {
            State = EngineState.Running;
            RaiseOpenerChanged(false);
        }
    }

    private void TriggerOpenerLocked()
    {
        StopAllSkillTimers();
        var generation = ++_openerGeneration;

        // A manual opener run also implies the helper should be live.
        if (!IsRunning) RaiseRunningChanged(true);

        RunOpener(generation);
    }

    // =====================================================================
    // Skill timers
    // =====================================================================

    private void RestartSkillTimers()
    {
        StopAllSkillTimers();
        if (!IsRunning || _config is null) return;

        for (var i = 0; i < SkillSlotCount; i++)
        {
            var key = _config.SkillKey(i);
            if (key.IsEmpty) continue;

            if (_config.SkillHold(i))
            {
                // Channel mode: one key-down, released when the helper stops or pauses.
                _skillHeld[i] = true;
                PostKeyDown(key);
                continue;
            }

            var delay = _config.SkillDelay(i);
            if (delay == 0) continue;

            var period = AdjustedDelay(delay);
            var slot = i;
            _skillHandles[i] = _timer.Schedule(
                () => FireSkillSlot(slot), period, period);
        }

        if (_config.ComboEnabled &&
            (!_config.ComboGeneratorKey.IsEmpty || !_config.ComboSpenderKey.IsEmpty))
        {
            _comboPhase = 0;
            _comboCount = 0;

            var interval = _config.ComboInterval > 0 ? _config.ComboInterval : 150;
            _comboHandle = _timer.Schedule(FireComboStep, interval, interval);
        }
    }

    private int _comboHandle;

    private int AdjustedDelay(int baseDelay)
    {
        if (_speedModActive && _config.SpeedModOffset != 0)
        {
            // Positive offset slows the loop down, negative speeds it up.
            var adjusted = baseDelay + _config.SpeedModOffset;
            return Math.Max(adjusted, 10);
        }

        return Math.Max(baseDelay, 10);
    }

    private bool _speedModActive;

    private void FireSkillSlot(int slot)
    {
        if (!IsRunning) return;

        // Quest key pauses everything.
        if (_questActive) return;

        // A held special key suppresses skills flagged for it.
        if (AnySpecialActive && _config.SkillCheck(slot)) return;

        var key = _config.SkillKey(slot);

        // Anti-disturbance: skip a left click that would land on the action bar or minimap.
        if (_config.AntiDisturbanceEnabled &&
            key.Type == InputType.MouseButton && key.MouseButton == MouseButton.Left &&
            DeadzoneFilter.IsCursorInUiDeadzone(_config.SelectedResolution))
        {
            return;
        }

        _lastFireTicks[slot] = Environment.TickCount64;
        Post(key);
    }

    private void FireComboStep()
    {
        if (!IsRunning || !_config.ComboEnabled) return;
        if (_questActive) return;
        if (AnySpecialActive) return;

        if (_comboPhase == 0)
        {
            if (!_config.ComboGeneratorKey.IsEmpty) Post(_config.ComboGeneratorKey);
            _comboCount++;
            if (_comboCount >= Math.Max(_config.ComboGeneratorCount, 1))
            {
                _comboPhase = 1;
                _comboCount = 0;
            }
        }
        else
        {
            if (!_config.ComboSpenderKey.IsEmpty) Post(_config.ComboSpenderKey);
            _comboCount++;
            if (_comboCount >= Math.Max(_config.ComboSpenderCount, 1))
            {
                _comboPhase = 0;
                _comboCount = 0;
            }
        }
    }

    private void StopAllSkillTimers()
    {
        for (var i = 0; i < SkillSlotCount; i++)
        {
            _timer.Cancel(_skillHandles[i]);
            _skillHandles[i] = 0;

            if (_skillHeld[i])
            {
                var key = _config?.SkillKey(i);
                if (key is { IsEmpty: false }) PostKeyUp(key);
                _skillHeld[i] = false;
            }
        }

        _timer.Cancel(_comboHandle);
        _comboHandle = 0;

        _speedModActive = false;
        _questActive = false;
        Array.Clear(_specialActive);

        for (var i = 0; i < SingleRepeatCount; i++) StopSingleRepeat(i);
    }

    private bool _questActive;

    private bool AnySpecialActive => _specialActive[0] || _specialActive[1] || _specialActive[2];

    // =====================================================================
    // Single-repeat keys
    // =====================================================================

    private void StartSingleRepeat(int index)
    {
        if (_singleHandles[index] != 0) return;

        var actionKey = _config.SingleRepeatAction(index);
        var delay = _config.SingleRepeatDelay(index);
        if (actionKey.IsEmpty || delay == 0) return;

        delay = Math.Max(delay, 10);
        _singleHandles[index] = _timer.Schedule(() => Post(actionKey), delay, delay);
    }

    private void StopSingleRepeat(int index)
    {
        _timer.Cancel(_singleHandles[index]);
        _singleHandles[index] = 0;
        _singleActiveKeys[index] = null;
    }

    // =====================================================================
    // Input event handling
    // =====================================================================

    /// <summary>Feeds a captured event into the engine.</summary>
    public void HandleInput(InputEvent evt)
    {
        lock (_gate) HandleInputLocked(evt);
    }

    private void HandleInputLocked(InputEvent evt)
    {
        var key = evt.Key;
        if (key.IsEmpty) return;

        var isDown = evt.IsDown;
        var isRepeat = evt.IsRepeat;

        // ---- 1. Single-repeat keys: active regardless of the main loop state ----
        for (var i = 0; i < SingleRepeatCount; i++)
        {
            var toggleKey = _config.SingleRepeatToggle(i);
            var matchesConfig = !toggleKey.IsEmpty && toggleKey == key;
            var matchesActive = _singleActiveKeys[i] is { } a && a == key;

            if (key.Type == InputType.MouseWheel && matchesConfig)
            {
                // A wheel has no key-up, so the toggle flips instead of latching. Ignoring
                // repeats stops the flip from strobing.
                if (!isRepeat)
                {
                    if (_singleHandles[i] != 0) StopSingleRepeat(i);
                    else StartSingleRepeat(i);
                }
            }
            else if (matchesConfig || matchesActive)
            {
                if (isDown)
                {
                    if (_singleHandles[i] == 0) StartSingleRepeat(i);
                }
                else
                {
                    StopSingleRepeat(i);
                }
            }
        }

        // ---- 2. Start / stop ----
        var isStart = _config.IsStartKey(key);
        var isStop = _config.IsStopKey(key);

        if (isStart && isStop)
        {
            // Same key for both: treat as a toggle, debounced against autorepeat.
            if (isDown && !isRepeat)
            {
                var now = Environment.TickCount64;
                if (now - _lastToggleMs < ToggleDebounceMs) return;
                _lastToggleMs = now;
                Toggle();
            }
            return;
        }

        if (isStart && isDown && !isRepeat && !IsRunning)
        {
            _lastToggleMs = Environment.TickCount64;
            StartLocked();
            return;
        }

        if (isStop && isDown && !isRepeat && IsRunning)
        {
            _lastToggleMs = Environment.TickCount64;
            StopLocked();
            return;
        }

        // ---- 3. Manual opener hotkey ----
        if (!_config.OpenerTriggerKey.IsEmpty && _config.OpenerTriggerKey == key)
        {
            if (isDown && !isRepeat)
            {
                TriggerOpenerLocked();
                return;
            }
        }

        if (!IsRunning) return;

        // ---- 4. Special keys ----
        for (var i = 0; i < SpecialKeyCount; i++)
        {
            var specialKey = _config.SpecialKey(i);
            if (specialKey.IsEmpty || specialKey != key) continue;

            if (_specialActive[i] == isDown) return; // duplicate event, no state change

            _specialActive[i] = isDown;
            ApplyHoldPauseForSpecialKey(isDown);

            if (!isDown) ReleaseSpecialKey(i);
            return;
        }

        // ---- 5. Quest key ----
        if (!_config.QuestKey.IsEmpty && _config.QuestKey == key)
        {
            _questActive = isDown;
            ApplyHoldPauseForQuestKey(isDown);
        }

        // ---- 6. Speed modifier ----
        if (!_config.SpeedModKey.IsEmpty && _config.SpeedModKey == key)
        {
            if (_config.SpeedModToggleMode)
            {
                if (isDown && !isRepeat)
                {
                    var now = Environment.TickCount64;
                    if (now - _lastSpeedToggleMs < ToggleDebounceMs) return;
                    _lastSpeedToggleMs = now;
                    _speedModActive = !_speedModActive;
                    RestartSkillTimers();
                }
            }
            else if (_speedModActive != isDown)
            {
                _speedModActive = isDown;
                RestartSkillTimers();
            }
        }
    }

    /// <summary>
    /// A pressed special key lifts every held (channel) skill; releasing it presses them
    /// back down.
    /// </summary>
    private void ApplyHoldPauseForSpecialKey(bool specialDown)
    {
        for (var s = 0; s < SkillSlotCount; s++)
        {
            if (!_config.SkillHold(s) || !_config.SkillCheck(s)) continue;

            var key = _config.SkillKey(s);
            if (key.IsEmpty) continue;

            if (specialDown && _skillHeld[s])
            {
                PostKeyUp(key);
                _skillHeld[s] = false;
            }
            else if (!specialDown && !_skillHeld[s])
            {
                _skillHeld[s] = true;
                PostKeyDown(key);
            }
        }
    }

    private void ApplyHoldPauseForQuestKey(bool questDown)
    {
        for (var s = 0; s < SkillSlotCount; s++)
        {
            if (!_config.SkillHold(s)) continue;

            var key = _config.SkillKey(s);
            if (key.IsEmpty) continue;

            if (questDown && _skillHeld[s])
            {
                PostKeyUp(key);
                _skillHeld[s] = false;
            }
            else if (!questDown && !_skillHeld[s])
            {
                _skillHeld[s] = true;
                PostKeyDown(key);
            }
        }
    }

    private void ReleaseSpecialKey(int index)
    {
        // Another special key still held means the suppression must stay in place.
        for (var other = 0; other < SpecialKeyCount; other++)
        {
            if (other != index && _specialActive[other]) return;
        }

        var cooldownWait = _config.SpecialKeyCooldown(index);

        for (var s = 0; s < SkillSlotCount; s++)
        {
            if (!_config.SkillCheck(s) || _config.SkillHold(s)) continue;

            var key = _config.SkillKey(s);
            if (key.IsEmpty) continue;

            if (!cooldownWait)
            {
                // Fire once now, then push the timer a full period out so the press is
                // not immediately repeated into a burst.
                Post(key);
                var period = AdjustedDelay(_config.SkillDelay(s));
                _timer.Reschedule(_skillHandles[s], period);
            }
            else
            {
                // Wait the skill's own delay from the moment the key was released.
                var period = AdjustedDelay(_config.SkillDelay(s));
                _timer.Reschedule(_skillHandles[s], period);
            }
        }
    }

    // =====================================================================
    // Posting
    // =====================================================================

    private void Post(InputKey key)
    {
        if (key.IsEmpty) return;
        if (Sink is { } sink)
        {
            sink.Send(key);
            return;
        }

        _sender.Send(key);
    }

    private void PostKeyDown(InputKey key)
    {
        if (key.IsEmpty) return;
        if (Sink is { } sink)
        {
            sink.KeyDown(key);
            return;
        }

        _sender.SendKeyDown(key);
    }

    private void PostKeyUp(InputKey key)
    {
        if (key.IsEmpty) return;
        if (Sink is { } sink)
        {
            sink.KeyUp(key);
            return;
        }

        _sender.SendKeyUp(key);
    }

    private void Schedule(int delayMs, Action action) => _timer.ScheduleOnce(action, delayMs);

    /// <summary>Waits for the input queue to flush, so a stop releases held keys promptly.</summary>
    public void FlushInput(TimeSpan timeout) => _sender.Drain(timeout);

    /// <summary>Diagnostics for the status bar.</summary>
    public EngineDiagnostics Diagnostics => new()
    {
        State = State,
        SchedulerTicks = _timer.TicksExecuted,
        MaxLatenessUs = _timer.MaxLatenessUs,
        DroppedInputs = _sender.DroppedCount,
        LastSendSucceeded = _sender.LastSendSucceeded,
        LastError = _sender.LastError,
    };

    public void Dispose()
    {
        Stop();
        _timer.Dispose();
        _sender.Dispose();
    }
}

public readonly record struct EngineDiagnostics(
    EngineState State,
    long SchedulerTicks,
    long MaxLatenessUs,
    long DroppedInputs,
    bool LastSendSucceeded,
    string? LastError);

/// <summary>Seam that lets tests observe input instead of injecting it.</summary>
public interface IInputSink
{
    void Send(InputKey key);
    void KeyDown(InputKey key);
    void KeyUp(InputKey key);
}
