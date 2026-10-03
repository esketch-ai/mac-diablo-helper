using System.Diagnostics;
using System.Runtime.InteropServices;
using DM_Helper.Core.Models;

namespace DM_Helper.Core.Interop;

/// <summary>Normalized input event, independent of whether it came from the hook or the UI.</summary>
public readonly record struct InputEvent(InputKey Key, bool IsDown, bool IsRepeat)
{
    public static InputEvent Down(InputKey k, bool repeat = false) => new(k, true, repeat);
    public static InputEvent Up(InputKey k) => new(k, false, false);
}

/// <summary>
/// Global input capture - the counterpart of <c>D3EventTapService</c>.
///
/// Uses <c>WH_KEYBOARD_LL</c> / <c>WH_MOUSE_LL</c> on a dedicated message-pump thread.
/// Events this app injected are identified by the <c>LLKHF_INJECTED</c> / <c>LLMHF_INJECTED</c>
/// flags and filtered out, which is what stopped the macOS build from recursing into itself
/// via <c>kCGEventSourceUserData</c>.
///
/// Low-level hooks are silently dropped by the OS if the callback takes longer than
/// <see cref="LowLevelTimeoutMs"/>, so the callback does nothing but marshal to a queue.
/// </summary>
public sealed class InputHookService : IDisposable
{
    private const int LowLevelTimeoutMs = 1000;

    private readonly HashSet<InputKey> _pressed = new();
    private readonly object _pressedGate = new();
    private readonly Queue<InputEvent> _events = new();
    private readonly object _eventGate = new();

    private LowLevelHookProc? _keyboardProc;
    private LowLevelHookProc? _mouseProc;
    private nint _keyboardHook;
    private nint _mouseHook;
    private Thread? _pumpThread;
    private uint _pumpThreadId;
    private volatile bool _running;
    private volatile bool _captureMode;

    /// <summary>Raised on the pump thread for every captured event.</summary>
    public event Action<InputEvent>? EventReceived;

    /// <summary>When set, events are routed here instead of <see cref="EventReceived"/>.</summary>
    public Func<InputEvent, bool>? CaptureHandler { get; set; }

    /// <summary>True while the low-level hooks are installed.</summary>
    public bool IsRunning => _running;

    /// <summary>
    /// Installs both hooks. Returns false off-Windows or when the hooks could not be
    /// created - the macOS build surfaced the same "permission needed" signal here.
    /// </summary>
    public bool Start()
    {
        if (_running) return true;
        if (!OperatingSystem.IsWindows()) return false;

        _keyboardProc = OnKeyboardEvent;
        _mouseProc = OnMouseEvent;

        var module = NativeMethods.GetModuleHandleW(null);

        _running = true;
        _pumpThread = new Thread(PumpLoop)
        {
            IsBackground = true,
            Name = "DM_Helper.InputHook",
            // LL hooks are dispatched on this thread; starving it gets them uninstalled.
            Priority = ThreadPriority.AboveNormal,
        };
        _pumpThread.Start();

        // Wait for the pump to publish its thread id before installing the hooks, so the
        // hooks are bound to the pump thread's message queue.
        var spin = Stopwatch.StartNew();
        while (_pumpThreadId == 0 && spin.ElapsedMilliseconds < 2000)
            Thread.Sleep(5);

        if (_pumpThreadId == 0)
        {
            _running = false;
            return false;
        }

        _keyboardHook = NativeMethods.SetWindowsHookExW(
            NativeConsts.WH_KEYBOARD_LL, _keyboardProc, module, 0);
        _mouseHook = NativeMethods.SetWindowsHookExW(
            NativeConsts.WH_MOUSE_LL, _mouseProc, module, 0);

        return _keyboardHook != 0 || _mouseHook != 0;
    }

    public void Stop()
    {
        if (!_running) return;
        _running = false;

        if (_pumpThreadId != 0)
            NativeMethods.PostThreadMessageW(_pumpThreadId, 0x0012 /* WM_QUIT */, IntPtr.Zero, IntPtr.Zero);

        _pumpThread?.Join(1500);
        _pumpThread = null;

        if (_keyboardHook != 0)
        {
            NativeMethods.UnhookWindowsHookEx(_keyboardHook);
            _keyboardHook = 0;
        }
        if (_mouseHook != 0)
        {
            NativeMethods.UnhookWindowsHookEx(_mouseHook);
            _mouseHook = 0;
        }

        lock (_pressedGate) _pressed.Clear();
        _keyboardProc = null;
        _mouseProc = null;
    }

    public void StartCapture() => _captureMode = true;

    public void StopCapture()
    {
        _captureMode = false;
        CaptureHandler = null;
    }

    public bool IsKeyPressed(InputKey key)
    {
        if (key.IsEmpty) return false;
        lock (_pressedGate) return _pressed.Contains(key);
    }

    public IReadOnlyCollection<InputKey> PressedKeys
    {
        get
        {
            lock (_pressedGate) return _pressed.ToArray();
        }
    }

    /// <summary>Drains buffered events; used by tests and by the engine's poll loop.</summary>
    public IReadOnlyList<InputEvent> Drain()
    {
        lock (_eventGate)
        {
            if (_events.Count == 0) return Array.Empty<InputEvent>();
            var copy = _events.ToArray();
            _events.Clear();
            return copy;
        }
    }

    // =====================================================================
    // Message pump
    // =====================================================================

    private void PumpLoop()
    {
        _pumpThreadId = NativeMethods.GetCurrentThreadId();

        while (_running)
        {
            while (NativeMethods.GetMessageW(out var msg, IntPtr.Zero, 0, 0) > 0)
            {
                NativeMethods.TranslateMessage(ref msg);
                NativeMethods.DispatchMessageW(ref msg);
            }

            if (!_running) break;
            Thread.Sleep(5);
        }
    }

    // =====================================================================
    // Hook callbacks - must stay fast; the OS drops the hook if they block
    // =====================================================================

    private nint OnKeyboardEvent(int code, nint wParam, nint lParam)
    {
        if (code == NativeConsts.HC_ACTION && lParam != 0)
        {
            var info = Marshal.PtrToStructure<KBDLLHOOKSTRUCT>(lParam);

            // Drop anything this process injected, else the macro retriggers itself.
            var injected = (info.flags & NativeConsts.LLKHF_INJECTED) != 0;

            if (!injected)
            {
                var isDown = wParam == 0x0100; // WM_KEYDOWN
                var vk = (Vk)info.vkCode;
                var key = InputKey.FromKey(vk);

                if (!key.IsEmpty)
                {
                    // Windows low-level hooks expose no autorepeat flag, but a KEYDOWN for
                    // a key we already hold is an autorepeat. The macOS build got this
                    // directly from kCGKeyboardEventAutorepeat.
                    var alreadyDown = IsKeyPressed(key);
                    var isRepeat = isDown && alreadyDown;

                    TrackPressed(key, isDown);
                    Publish(new InputEvent(key, isDown, isRepeat));
                }
            }
        }

        return NativeMethods.CallNextHookEx(0, code, wParam, lParam);
    }

    private nint OnMouseEvent(int code, nint wParam, nint lParam)
    {
        if (code == NativeConsts.HC_ACTION && lParam != 0)
        {
            var info = Marshal.PtrToStructure<MSLLHOOKSTRUCT>(lParam);

            if ((info.flags & NativeConsts.LLMHF_INJECTED) == 0)
            {
                var wm = (uint)wParam.ToInt64();

                switch (wm)
                {
                    case 0x0201: Publish(Button(InputKey.FromMouse(MouseButton.Left), true)); break;
                    case 0x0202: Publish(Button(InputKey.FromMouse(MouseButton.Left), false)); break;
                    case 0x0204: Publish(Button(InputKey.FromMouse(MouseButton.Right), true)); break;
                    case 0x0205: Publish(Button(InputKey.FromMouse(MouseButton.Right), false)); break;
                    case 0x0207: Publish(Button(InputKey.FromMouse(MouseButton.Middle), true)); break;
                    case 0x0208: Publish(Button(InputKey.FromMouse(MouseButton.Middle), false)); break;
                    case 0x020B:
                    case 0x020C:
                    {
                        var b = (info.mouseData >> 16) & 0xFFFF;
                        var btn = b == NativeConsts.XBUTTON1 ? MouseButton.XButton1 : MouseButton.XButton2;
                        Publish(Button(InputKey.FromMouse(btn), wm == 0x020B));
                        break;
                    }
                    case 0x020A: // WM_MOUSEWHEEL
                    {
                        var delta = unchecked((short)((info.mouseData >> 16) & 0xFFFF));
                        var dir = delta > 0 ? WheelDirection.Up : WheelDirection.Down;
                        // The wheel has no key-up, so report it as a down-only event.
                        Publish(new InputEvent(InputKey.FromWheel(dir), true, false));
                        break;
                    }
                }
            }
        }

        return NativeMethods.CallNextHookEx(0, code, wParam, lParam);
    }

    private InputEvent Button(InputKey key, bool down) => new(key, down, false);

    private void TrackPressed(InputKey key, bool down)
    {
        lock (_pressedGate)
        {
            if (down) _pressed.Add(key);
            else _pressed.Remove(key);
        }
    }

    private void Publish(InputEvent evt)
    {
        // Capture mode swallows the event so it cannot also drive the macro - the
        // behaviour the macOS build implemented by returning early from the tap callback.
        if (_captureMode && CaptureHandler is { } handler)
        {
            try
            {
                handler(evt);
            }
            catch
            {
                // A misbehaving capture handler must not kill the hook chain.
            }
            return;
        }

        lock (_eventGate) _events.Enqueue(evt);
        EventReceived?.Invoke(evt);
    }

    public void Dispose() => Stop();
}
