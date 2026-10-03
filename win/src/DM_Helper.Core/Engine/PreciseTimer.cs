using System.Diagnostics;

namespace DM_Helper.Core.Engine;

/// <summary>
/// Precise periodic scheduler, replacing the <c>dispatch_source</c> timers the macOS build
/// ran on its serial GCD queue.
///
/// <see cref="System.Threading.Timer"/> is not good enough: on Windows 11 it can drift by up
/// to ~15ms, which compounds across a 120ms skill rotation. This instead walks a
/// deadline-ordered queue on a dedicated thread, sleeping until shortly before each
/// deadline and then spinning. That reproduces the ~1ms leeway GCD gave the macOS build.
///
/// Periods are computed from the previous deadline rather than from "now", so a slow action
/// does not permanently shift the cadence.
/// </summary>
public sealed class PreciseTimer : IDisposable
{
    /// <summary>Stop sleeping this many ms before a deadline and spin instead.</summary>
    private const int SpinWindowMs = 2;

    /// <summary>Idle poll interval when nothing is scheduled.</summary>
    private const int IdleSleepMs = 2;

    private readonly object _gate = new();
    private readonly PriorityQueue<(long Due, int Handle, int Generation), long> _queue = new();
    private readonly Dictionary<int, Entry> _entries = new();
    private readonly HashSet<int> _cancelled = new();
    private readonly Stopwatch _clock = Stopwatch.StartNew();

    private readonly Thread _thread;
    private long _tickLatenessMaxUs;
    private int _nextHandle = 1;
    private volatile bool _running;

    /// <summary>Total actions executed; lets tests confirm the loop ran.</summary>
    public long TicksExecuted { get; private set; }

    /// <summary>Worst observed lateness, in microseconds, for diagnostics.</summary>
    public long MaxLatenessUs => Interlocked.Read(ref _tickLatenessMaxUs);

    /// <summary>Number of live schedules.</summary>
    public int Count
    {
        get
        {
            lock (_gate) return _entries.Count;
        }
    }

    public PreciseTimer(string name = "DM_Helper.Timer")
    {
        _thread = new Thread(Loop)
        {
            IsBackground = true,
            Name = name,
            // Starving this thread causes dropped frames and, historically, input latency.
            Priority = ThreadPriority.AboveNormal,
        };
    }

    /// <summary>
    /// Runs <paramref name="action"/> after <paramref name="initialDelayMs"/>, then every
    /// <paramref name="periodMs"/> if that is greater than zero.
    /// </summary>
    public int Schedule(Action action, int initialDelayMs, int periodMs = 0)
    {
        ArgumentNullException.ThrowIfNull(action);

        int handle;
        long due;

        lock (_gate)
        {
            if (!_running)
            {
                _running = true;
                _thread.Start();
            }

            handle = _nextHandle++;
            due = NowMs + Math.Max(initialDelayMs, 0);
            var entry = new Entry(action, periodMs, due);
            _entries[handle] = entry;
            _queue.Enqueue((due, handle, entry.Generation), due);
        }

        return handle;
    }

    /// <summary>Runs <paramref name="action"/> once after <paramref name="delayMs"/>.</summary>
    public int ScheduleOnce(Action action, int delayMs) => Schedule(action, delayMs, 0);

    public void Cancel(int handle)
    {
        if (handle == 0) return;
        lock (_gate)
        {
            if (_entries.Remove(handle)) _cancelled.Add(handle);
        }
    }

    /// <summary>
    /// Reschedules an existing handle from now, used when the speed modifier changes a
    /// skill's interval mid-run.
    /// </summary>
    public void Reschedule(int handle, int delayMs)
    {
        if (handle == 0) return;
        lock (_gate)
        {
            if (!_entries.TryGetValue(handle, out var entry)) return;

            // The queue may still hold the old due time for this handle. Bumping the
            // generation invalidates that stale node so it is skipped when popped,
            // otherwise the action fires twice around a special-key release.
            entry.Generation++;
            entry.Due = NowMs + Math.Max(delayMs, 0);
            _queue.Enqueue((entry.Due, handle, entry.Generation), entry.Due);
        }
    }

    public void CancelAll()
    {
        lock (_gate)
        {
            foreach (var h in _entries.Keys) _cancelled.Add(h);
            _entries.Clear();
        }
    }

    public void Dispose()
    {
        CancelAll();
        _running = false;
    }

    private long NowMs => (long)_clock.Elapsed.TotalMilliseconds;

    private void Loop()
    {
        var spin = new SpinWait();

        while (_running)
        {
            Action? toRun = null;
            long firedDue = 0;
            long sleepMs = 0;

            lock (_gate)
            {
                if (_entries.Count == 0)
                {
                    sleepMs = IdleSleepMs;
                }
                else if (_queue.TryPeek(out var head, out _) && head.Due <= NowMs)
                {
                    _queue.TryDequeue(out _, out _);
                    (toRun, firedDue) = ResolveDue(head.Handle, head.Generation);
                }
                else if (_queue.TryPeek(out var next, out _))
                {
                    var delta = next.Due - NowMs;
                    sleepMs = delta > SpinWindowMs ? delta - SpinWindowMs : 0;
                }
                else
                {
                    // Every queued head is cancelled; drain and let the next
                    // Schedule/CancelAll settle the queue.
                    while (_queue.TryDequeue(out _, out _))
                    {
                    }
                    sleepMs = IdleSleepMs;
                }
            }

            if (toRun is not null)
            {
                RecordLateness(firedDue);
                try
                {
                    toRun();
                }
                catch
                {
                    // One misbehaving action must not take the scheduler down.
                }
                TicksExecuted++;
                spin = new SpinWait();
                continue;
            }

            if (sleepMs > 0)
            {
                Thread.Sleep((int)sleepMs);
                spin = new SpinWait();
            }
            else
            {
                spin.SpinOnce();
            }
        }
    }

    /// <summary>
    /// Pops the head entry, re-arming it when it repeats, and returns the action plus the
    /// deadline it was scheduled for. Must be called under the lock.
    /// </summary>
    private (Action? Action, long Due) ResolveDue(int handle, int generation)
    {
        if (_cancelled.Contains(handle))
        {
            _cancelled.Remove(handle);
            _entries.Remove(handle);
            return (null, 0);
        }

        if (!_entries.TryGetValue(handle, out var entry)) return (null, 0);

        // A stale node left behind by Reschedule: drop it without firing.
        if (entry.Generation != generation) return (null, 0);

        var due = entry.Due;

        if (entry.PeriodMs > 0)
        {
            var next = due + entry.PeriodMs;
            if (next <= NowMs) next = NowMs + entry.PeriodMs;
            entry.Due = next;
            _queue.Enqueue((next, handle, entry.Generation), next);
        }
        else
        {
            _entries.Remove(handle);
        }

        return (entry.Action, due);
    }

    /// <summary>
    /// Tracks how far past its deadline a tick ran, so jitter can be verified in a test
    /// rather than guessed at.
    /// </summary>
    private void RecordLateness(long dueMs)
    {
        var lateUs = (NowMs - dueMs) * 1000;
        if (lateUs > 0) InterlockedMax(ref _tickLatenessMaxUs, lateUs);
    }

    private static void InterlockedMax(ref long target, long value)
    {
        long current;
        while (value > (current = Interlocked.Read(ref target)))
        {
            if (Interlocked.CompareExchange(ref target, value, current) == current) return;
        }
    }

    private sealed class Entry
    {
        public Entry(Action action, int periodMs, long due)
        {
            Action = action;
            PeriodMs = periodMs;
            Due = due;
        }

        public Action Action { get; }
        public int PeriodMs { get; }
        public long Due { get; set; }

        /// <summary>Invalidates stale queue nodes after a Reschedule.</summary>
        public int Generation { get; set; }
    }
}
