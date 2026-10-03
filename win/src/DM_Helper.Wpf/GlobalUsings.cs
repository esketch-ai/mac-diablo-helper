// Using WinForms for the tray NotifyIcon drags System.Windows.Forms and System.Drawing into
// scope, which collides with WPF on a dozen common names. These aliases pin the WPF meaning
// project-wide so individual files stay free of qualifications. Services/TrayIconController.cs
// deliberately opts into the WinForms names instead.

global using Application = System.Windows.Application;
global using Window = System.Windows.Window;
global using UserControl = System.Windows.Controls.UserControl;
global using MessageBox = System.Windows.MessageBox;
global using RadioButton = System.Windows.Controls.RadioButton;
global using Localization = DM_Helper.Core.Services.Localization;
global using InputType = DM_Helper.Core.Models.InputType;
global using MouseButton = DM_Helper.Core.Interop.MouseButton;
global using KeyEventArgs = System.Windows.Input.KeyEventArgs;
global using Key = System.Windows.Input.Key;
global using Cursors = System.Windows.Input.Cursors;
global using MouseButtonEventArgs = System.Windows.Input.MouseButtonEventArgs;
global using KeyboardFocusChangedEventArgs = System.Windows.Input.KeyboardFocusChangedEventArgs;
global using SelectionChangedEventArgs = System.Windows.Controls.SelectionChangedEventArgs;
global using TextChangedEventArgs = System.Windows.Controls.TextChangedEventArgs;
global using SaveFileDialog = Microsoft.Win32.SaveFileDialog;
global using OpenFileDialog = Microsoft.Win32.OpenFileDialog;
