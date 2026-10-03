using System.Collections.Concurrent;
using DM_Helper.Core.Interop;
using DM_Helper.Core.Models;

namespace DM_Helper.Core.Engine;

/// <summary>
/// Runs input actions off the scheduling thread.
///
/// The macOS build called <c>usleep(25000)</c> inline on its engine queue to hold a key
/// down, which stalled every other timer slot by 25ms. Here the hold happens on this
/// thread instead, so a 25ms hold never delays a 120ms skill rotation.
/// </summary>
public sealed class InputSender : IDisposable
{
    private readonly ConcurrentQueue<Action> _queue = new();
    private readonly Thread _thread;
    private volatile bool _running;
    private volatile bool _draining;

    /// <summary>Actions dropped because the queue exceeded <see cref="MaxQueueDepth"/>.</summary>
    public long DroppedCount { get; private set; }

    /// <summary>False once a send failed, which normally means UIPI blocked injection.</summary>
    public bool LastSendSucceeded { get; private set; } = true;

    /// <summary>Human-readable reason injection was rejected, for the status bar.</summary>
    public string? LastError { get; private set; }

    private const int MaxQueueDepth = 256;

    public InputSender()
    {
        _thread = new Thread(Loop)
        {
            IsBackground = true,
            Name = "DM_Helper.InputSender",
            Priority = ThreadPriority.AboveNormal,
        };
    }

    public void Start()
    {
        if (_running) return;
        _running = true;
        _draining = true;
        _thread.Start();
    }

    /// <summary>Queues a fire-and-forget input action.</summary>
    public void Enqueue(Action action)
    {
        if (_queue.Count >= MaxQueueDepth)
        {
            DroppedCount++;
            return;
        }

        _queue.Enqueue(action);
    }

    /// <summary>Queues a complete key press (down, hold, up).</summary>
    public void SendKey(InputKey key, int holdMs = InputPoster.KeyHoldMs) =>
        Enqueue(() => Record(InputPoster.PostKey(key, holdMs)));

    /// <summary>Queues a mouse or wheel action.</summary>
    public void Send(InputKey key) => Enqueue(() => Record(InputPoster.PostKey(key)));

    /// <summary>Queues a bare key-down, for channel / hold-mode skills.</summary>
    public void SendKeyDown(InputKey key) => Enqueue(() => Record(InputPoster.PostKeyDown(key)));

    /// <summary>Queues a bare key-up, used to pause and resume a held skill.</summary>
    public void SendKeyUp(InputKey key) => Enqueue(() => Record(InputPoster.PostKeyUp(key)));

    private void Record(bool ok)
    {
        if (ok) return;
        LastSendSucceeded = false;
        LastError ??=
            "입력이 게임에 전달되지 않았습니다. 관리자 권한으로 실행 중인지 확인하세요. "
            + "(SendInput blocked - check that the app is running elevated.)";
    }

    /// <summary>
    /// Blocks until the queue drains. Used on stop so held keys are released before the
    /// process goes quiet, and by tests to assert on a deterministic set of sends.
    /// </summary>
    public void Drain(TimeSpan timeout)
    {
        var deadline = DateTime.UtcNow + timeout;
        while (DateTime.UtcNow < deadline)
        {
            if (_queue.IsEmpty && !_draining) return;
            Thread.Sleep(2);
        }
    }

    private void Loop()
    {
        while (_draining || !_queue.IsEmpty)
        {
            if (_queue.TryDequeue(out var action))
            {
                try
                {
                    action();
                }
                catch
                {
                    // Never let a single failed send kill the pump.
                }
            }
            else
            {
                Thread.Sleep(1);
            }
        }
    }

    public void Dispose()
    {
        _draining = false;
        _running = false;
        _thread.Join(500);
    }
}
