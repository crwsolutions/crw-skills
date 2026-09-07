---
name: net-maui-popups
description: Use this skill for .NET MAUI popup and snackbar implementation. It covers built-in alerts, inline popups, and the CommunityToolkit Popup v2 API (DI-based, Shell navigation, Popup<T> results, options, customization) plus the Toolkit Snackbar.
---

# .NET MAUI Popups

Standard implementation patterns for popups in .NET MAUI apps, based on the **.NET MAUI Community Toolkit Popup v2** API (the `Popup` view + `IPopupService` introduced for ViewModel-based popups), plus the Toolkit **Snackbar**.

This skill contains the full instructions. Follow them in order: use the quick decision guide to pick the pattern, then copy the matching pattern's code, adapting names to the target project.

## When to use

- The task asks to add, show, or change a **popup**, **dialog**, or **confirmation prompt** in a .NET MAUI app.
- The task asks to show **transient feedback** to the user (snackbar/toast).
- The task registers popups with the Community Toolkit (usually in `MauiProgram.cs`, or an app-wide DI extension method).

## Prerequisites

All popup patterns (except the built-in alerts) require the **CommunityToolkit.Maui** and **CommunityToolkit.Mvvm** NuGet packages:

```xml
<!-- .csproj -->
<PackageReference Include="CommunityToolkit.Maui" Version="*" />
<PackageReference Include="CommunityToolkit.Mvvm" Version="*" />
```

> **Version note:** CommunityToolkit.Maui 15.x requires `Microsoft.Maui.Controls >= 10.0.90`. A fresh MAUI 10 template may pin an older patch (e.g. 10.0.20), which fails the restore with NU1605 (package downgrade). Reference `Microsoft.Maui.Controls` directly at a compatible version.

The ViewModel-based patterns (3–5) use `ObservableObject`, `[ObservableProperty]` and `[RelayCommand]` from CommunityToolkit.Mvvm. These types live in **sub-namespaces** — the bare `using CommunityToolkit.Mvvm;` is not enough:

```csharp
using CommunityToolkit.Mvvm.ComponentModel; // ObservableObject, [ObservableProperty]
using CommunityToolkit.Mvvm.Input;          // [RelayCommand]
```

and `UseMauiCommunityToolkit()` in `MauiProgram.cs`, chained to `UseMauiApp<T>()` (the toolkit analyzer MCT001 enforces the chaining):

```csharp
builder.UseMauiApp<App>()
       .UseMauiCommunityToolkit(); // required for popups and snackbar
```

## Quick decision guide

Pick the **simplest** pattern that satisfies the requirement:

| Scenario | Pattern |
|---|---|
| Informational message, yes/no question, choice list, or simple text input; no custom layout needed | [1. Simple (out of the box)](#1-simple-out-of-the-box) |
| Custom layout, but a one-off throwaway popup; no ViewModel, no DI registration | [2. Simple inline](#2-simple-inline) |
| Reusable custom popup; logic belongs in a ViewModel | [3. Complex (DI + Shell)](#3-complex-di--shell) |
| Same as 3, but the popup needs data passed **in** | [4. Complex with input](#4-complex-with-input) |
| Same as 3, but the popup must return a value **out** (e.g. a confirmation result) | [5. Complex with output](#5-complex-with-output) |
| A long-running/progress popup you keep open and **close later from elsewhere** (no result awaited) | [6. Progress (fire-and-forget)](#6-progress-fire-and-forget) |
| Transient, non-blocking feedback at the bottom of the screen | [8. Snackbar](#8-snackbar) |

For any custom popup: set look & feel with [PopupOptions](#7-options), app-wide styling with [Customizing](#9-customizing).

## 1. Simple (out of the box)

Built-in `Page` methods. No package, no ViewModel, no registration. Use whenever no custom layout is required.

```csharp
// Informational message
await DisplayAlertAsync("Title", "This is a message", "OK");

// Yes/No question
bool confirmed = await DisplayAlertAsync("Confirm", "Do you want to continue?", "Yes", "No");

// Choice list (Action Sheet); return value is the selected option or null
string? option = await DisplayActionSheetAsync("Pick an option", "Cancel", null, "Option 1", "Option 2");

// Text input; return value is the entered text or null
string? text = await DisplayPromptAsync("Input", "What is your name?");
```

> The synchronous `DisplayAlert`/`DisplayActionSheet` overloads are **obsolete in MAUI 10** (CS0618); always use the `Async` versions.

> **Calling from a ViewModel:** all three are `Page` methods. From a ViewModel, access the current page via `Application.Current!.Windows[0]!.Page!` (e.g. `await Application.Current!.Windows[0]!.Page!.DisplayAlertAsync("Error", message, "OK");`). Null-forgiving operators are acceptable when the app guarantees an active window/page — typical for a single-window desktop MAUI app.

## 2. Simple inline

A custom-layout popup built entirely in C# inside the page's code-behind. No separate ViewModel, no DI registration. Use for one-off popups only.

```csharp
using CommunityToolkit.Maui;          // PopupOptions
using CommunityToolkit.Maui.Views;    // Popup
using Microsoft.Maui.Controls.Shapes; // RoundRectangle

// In your page's code-behind (e.g. MainPage.xaml.cs)
private async void OnOpenInlinePopupClicked(object? sender, EventArgs e)
{
    var closeButton = new Button { Text = "Got it" };

    // Inline: the popup content is built entirely from code.
    // Set an explicit BackgroundColor and Label TextColor so the text is visible
    // on any theme (see Section 9.2: default colors can render white-on-white).
    var inlinePopup = new Popup
    {
        BackgroundColor = Colors.White,
        Content = new VerticalStackLayout
        {
            Padding = 20,
            WidthRequest = 280,
            Spacing = 12,
            Children =
            {
                new Label
                {
                    Text = "Inline message",
                    FontAttributes = FontAttributes.Bold,
                    TextColor = Colors.Black,
                    HorizontalOptions = LayoutOptions.Center
                },
                new Label
                {
                    Text = "This is a lightweight popup built entirely from code.",
                    TextColor = Colors.Black,
                    HorizontalOptions = LayoutOptions.Center
                },
                closeButton
            }
        }
    };

    closeButton.Clicked += async (_, _) => await Shell.Current.ClosePopupAsync();

    await Shell.Current.ShowPopupAsync(inlinePopup, new PopupOptions
    {
        PageOverlayColor = Color.FromArgb("#99000000"),
        Shape = new RoundRectangle { CornerRadius = 12 }
    });
}
```

## 3. Complex (DI + Shell)

**This is the preferred pattern for all custom, reusable popups.** The popup is a separate View + ViewModel pair, registered in DI, shown through the injected `IPopupService` with `Shell.Current` as the navigation context. The DI + `IPopupService` approach is the recommended default; hand-instantiating a popup with `new` is **not preferred** and is limited to stateless, parameterized popups (Section 2) or the fire-and-forget progress pattern (Section 6).

### 3.1 Register in `MauiProgram.cs`

Register the pair where the app's DI setup lives. That is normally `MauiApp.CreateBuilder()` in `MauiProgram.CreateMauiApp()`; in some projects that setup is an extension method (e.g. `builder.AddAppServices()`). The registration call below is the same wherever `builder.Services` is configured — just put it next to the other page/service registrations in that project.

```csharp
using CommunityToolkit.Maui;

public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        var builder = MauiApp.CreateBuilder();
        builder
            .UseMauiApp<App>()
            .UseMauiCommunityToolkit(); // required for popups

        // Register the popup View + ViewModel pair
        builder.Services.AddTransientPopup<MyPopup, MyPopupViewModel>();

        // Register other pages and services as usual
        builder.Services.AddTransient<MainPage, MainPageViewModel>();

        return builder.Build();
    }
}
```

Available registrations:

| Method | Result |
|---|---|
| `AddTransientPopup<TView, TViewModel>()` | View + ViewModel, new instance per show (default choice) |
| `AddSingletonPopup<TView, TViewModel>()` | View + ViewModel, one shared instance |
| `AddScopedPopup<TView, TViewModel>()` | View + ViewModel, one instance per DI scope |
| `AddTransientPopup<TView>()` | View only (no ViewModel; the view may still create its own VM) |

### 3.2 Show from a ViewModel

Inject `IPopupService` and always pass `Shell.Current` as the navigation context. All methods that return a `Task` use the **`Async` suffix**.

```csharp
using CommunityToolkit.Maui;

public partial class MainPageViewModel : ObservableObject
{
    private readonly IPopupService _popupService;

    public MainPageViewModel(IPopupService popupService)
    {
        _popupService = popupService;
    }

    [RelayCommand]
    private async Task OpenMyPopupAsync()
    {
        var options = new PopupOptions
        {
            CanBeDismissedByTappingOutsideOfPopup = false // force explicit dismissal
        };

        await _popupService.ShowPopupAsync<MyPopupViewModel>(Shell.Current, options);
    }
}
```

### 3.3 The popup View (code-behind)

The toolkit resolves and injects the registered ViewModel through the constructor; assign it to `BindingContext`.

```csharp
using CommunityToolkit.Maui.Views;

namespace MyApp.Views;

public partial class MyPopup : Popup
{
    public MyPopup(MyPopupViewModel viewModel)
    {
        InitializeComponent();
        BindingContext = viewModel;
    }
}
```

### 3.4 The popup ViewModel

Close the popup with `Shell.Current.ClosePopupAsync()`. The `using CommunityToolkit.Maui.Extensions;` directive is required for the `ClosePopupAsync` extension method.

```csharp
using CommunityToolkit.Maui.Extensions;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

public partial class MyPopupViewModel : ObservableObject
{
    [ObservableProperty]
    private string _message = "Injected via dependency injection";

    [RelayCommand]
    private async Task ClosePopupAsync()
    {
        await Shell.Current.ClosePopupAsync();
    }
}
```

## 4. Complex with input

Pass data into a registered popup through a `Dictionary<string, object>` as `shellParameters`. The **popup View** or its **ViewModel** implements `IQueryAttributable` to receive the values.

Caller:

```csharp
[RelayCommand]
private async Task OpenWithInputAsync()
{
    var parameters = new Dictionary<string, object>
    {
        ["Title"] = "Hello from the caller",
        ["Description"] = "This text was passed in using IQueryAttributable"
    };

    await _popupService.ShowPopupAsync<MyPopupViewModel>(Shell.Current, null, parameters);
}
```

Receiver — ViewModel:

```csharp
using CommunityToolkit.Maui.Extensions;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Maui; // IQueryAttributable

public partial class MyPopupViewModel : ObservableObject, IQueryAttributable
{
    [ObservableProperty]
    private string _title = string.Empty;

    [ObservableProperty]
    private string _description = string.Empty;

    void IQueryAttributable.ApplyQueryAttributes(IDictionary<string, object> query)
    {
        Title = (string)query["Title"];
        Description = (string)query["Description"];
    }

    [RelayCommand]
    private async Task ClosePopupAsync()
    {
        await Shell.Current.ClosePopupAsync();
    }
}
```

> **Note:** `IQueryAttributable` lives in the `Microsoft.Maui` namespace (not `CommunityToolkit.Maui.Core`). For returning a value out of the popup, use `Popup<TResult>` (Section 5).

## 5. Complex with output

When the caller needs a value **back** from the popup, use `Popup<TResult>`. The caller awaits a typed result; the popup closes itself with `CloseAsync(result)`.

### 5.1 The popup View (code-behind + XAML)

```csharp
using CommunityToolkit.Maui.Views;

namespace MyApp.Views;

public partial class MyResultPopup : Popup<bool>
{
    public MyResultPopup(MyResultPopupViewModel viewModel)
    {
        InitializeComponent();
        BindingContext = viewModel;
    }

    async void OnAcceptClicked(object? sender, EventArgs e) => await CloseAsync(true);
    async void OnDeclineClicked(object? sender, EventArgs e) => await CloseAsync(false);
}
```

```xml
<toolkit:Popup xmlns="http://schemas.microsoft.com/dotnet/2021/maui"
               xmlns:x="http://schemas.microsoft.com/winfx/2009/xaml"
               xmlns:toolkit="http://schemas.microsoft.com/dotnet/2022/maui/toolkit"
               xmlns:system="clr-namespace:System;assembly=mscorlib"
               xmlns:vm="clr-namespace:MyApp.ViewModels"
               x:Class="MyApp.Views.MyResultPopup"
               x:DataType="vm:MyResultPopupViewModel"
               x:TypeArguments="system:Boolean"
               Padding="10">

    <VerticalStackLayout Spacing="10">
        <Label Text="{Binding PromptText}" />
        <Button Text="Yes" Clicked="OnAcceptClicked" />
        <Button Text="No" Clicked="OnDeclineClicked" />
    </VerticalStackLayout>
</toolkit:Popup>
```

> **Important:** `x:TypeArguments` must match the generic argument of the code-behind class (`Popup<bool>`), and the code-behind must call `InitializeComponent()`. `x:DataType` points to the injected ViewModel for compile-time binding checks.

### 5.2 The popup ViewModel

Plain ViewModel. If the close should depend on state (e.g. validation), keep that logic in the ViewModel and let the popup's code-behind call `CloseAsync(result)` afterwards.

```csharp
using CommunityToolkit.Mvvm.ComponentModel;

public partial class MyResultPopupViewModel : ObservableObject
{
    public string PromptText { get; } = "Do you agree?";
}
```

### 5.3 Closing with a result

`CloseAsync(result)` is a method on the **popup View** (`Popup<T>`), not on the ViewModel. That is by design: the close is a pure view concern (the user tapped a button), which is why the toolkit's own sample wires it in the code-behind.

Keep the result type consistent in **all three** places — they must agree on `T`:

1. The code-behind class: `Popup<T>`
2. The XAML root: `x:TypeArguments="system:T"`
3. The caller's generic call: `ShowPopupAsync<TPopup, T>(...)`

### 5.4 The caller

Use the generic overload `ShowPopupAsync<T, TResult>(...)` and check `WasDismissedByTappingOutsideOfPopup` before trusting `Result`:

```csharp
[RelayCommand]
private async Task OpenResultPopupAsync()
{
    var result = await _popupService.ShowPopupAsync<MyResultPopup, bool>(Shell.Current);

    if (result.WasDismissedByTappingOutsideOfPopup)
    {
        return; // dismissed by tapping outside; Result is null/default
    }

    if (result.Result is true)
    {
        // User accepted
    }
    // else: user declined
}
```

## 6. Progress (fire-and-forget)

Use the non-async `ShowPopup` when the popup represents **ongoing work** that must stay open and be **closed later from another code path** — e.g. a progress/cancel dialog for a long-running operation. Unlike Sections 3–5, the caller does not await a result; the popup is closed programmatically once the work finishes (or the user cancels). The toolkit's docs document `ShowPopup` + a later `ClosePopupAsync()` as the "programmatically closing a popup" path, so this is a first-class pattern, not a workaround.

### 6.1 The popup View

A plain `Popup` (no result type is needed). Keep it self-contained; the work's state lives in the caller.

```csharp
using CommunityToolkit.Maui.Views;

namespace MyApp.Views;

public partial class BusyPopup : Popup
{
    public BusyPopup()
    {
        InitializeComponent();
    }
}
```

```xml
<toolkit:Popup xmlns="http://schemas.microsoft.com/dotnet/2021/maui"
               xmlns:x="http://schemas.microsoft.com/winfx/2009/xaml"
               xmlns:toolkit="http://schemas.microsoft.com/dotnet/2022/maui/toolkit"
               x:Class="MyApp.Views.BusyPopup"
               BackgroundColor="Black" WidthRequest="400">

    <VerticalStackLayout Spacing="15" Padding="10" HorizontalOptions="Center">
        <Label Text="Working..." FontAttributes="Bold" TextColor="White" HorizontalOptions="Center" />
        <ActivityIndicator IsRunning="True" Color="White" />
    </VerticalStackLayout>
</toolkit:Popup>
```

### 6.2 Show it, do the work, close it

```csharp
[RelayCommand]
private async Task ClassifyAsync(CancellationTokenSource cts)
{
    var popup = new BusyPopup();

    // Fire-and-forget: ShowPopup is non-async and returns immediately, so the popup
    // stays open while the work runs. Do NOT use `await ShowPopupAsync(...)` here —
    // that Task only completes when the popup is closed, so awaiting it would block
    // until after the work (deadlock).
    Shell.Current.ShowPopup(popup, new PopupOptions
    {
        CanBeDismissedByTappingOutsideOfPopup = false
    });

    try
    {
        await DoLongRunningWorkAsync(cts.Token); // the Cancel button calls cts.Cancel()
    }
    catch (OperationCanceledException)
    {
        // cancelled by the user
    }
    finally
    {
        // Always close from a known point so the popup never lingers.
        await Shell.Current.ClosePopupAsync();
    }
}
```

> **Notes:**
> - `ShowPopup` (non-async) is valid and documented; it just doesn't hand you an `IPopupResult`. Prefer `ShowPopupAsync` whenever you *can* await the close, because it makes the "popup is gone" moment explicit.
> - For a cancel button that cancels the work, hand the popup a `CancellationTokenSource` (via its constructor) and call `cts.Cancel()` from the button; the `finally` block then closes the popup.
> - Because the close happens outside the show call, there is no `WasDismissedByTappingOutsideOfPopup` result to check. Set `CanBeDismissedByTappingOutsideOfPopup = false` so the only way out is your own `ClosePopupAsync`.

## 7. Options

`PopupOptions` controls appearance and behavior. Pass them to any `ShowPopupAsync` call (or set them per popup on the `Popup` root, see [9. Customizing](#9-customizing)).

```csharp
var options = new PopupOptions
{
    CanBeDismissedByTappingOutsideOfPopup = false,
    PageOverlayColor = Color.FromArgb("#B3000000"), // semi-transparent dark overlay
    Shape = new RoundRectangle
    {
        CornerRadius = 16,
        Stroke = Colors.LightGray,
        StrokeThickness = 1
    },
    Shadow = new Shadow
    {
        Brush = new SolidColorBrush(Colors.Black),
        Opacity = 0.3f,
        Radius = 8
    }
};

await _popupService.ShowPopupAsync<MyPopupViewModel>(Shell.Current, options);
```

| Property | Type | Description |
|---|---|---|
| `CanBeDismissedByTappingOutsideOfPopup` | `bool` | User can tap outside to close. Default `true`. On Android, `false` also disables the hardware back button. |
| `OnTappingOutsideOfPopup` | `Action` | Callback invoked when the user taps outside. |
| `PageOverlayColor` | `Color` | Color of the overlay behind the popup. Use alpha for translucency. |
| `Shape` | `Shape` | Border around the popup content (e.g. `RoundRectangle`). `null` removes the border. |
| `Shadow` | `Shadow` | Shadow behind the popup. `null` removes the shadow. |
| `BindingContext` | `object` | Optional. Sets the popup's `BindingContext` to the caller's object (useful when the popup ViewModel reads from the caller). Prefer `shellParameters` (Section 4) for passing data in. |

Positioning is set on the popup itself (not in `PopupOptions`), via `HorizontalOptions`/`VerticalOptions` (`Start`/`Center`/`End` in each dimension):

```csharp
// Bottom-anchored, full width (e.g. bottom sheet style)
var options = new PopupOptions { ... };
// On the Popup XAML/root:
// HorizontalOptions="Fill" VerticalOptions="End"
```

## 8. Snackbar

Transient, non-blocking feedback shown at the bottom of the screen for a configurable duration. No popup dismissal, no result, no navigation context needed. **Prefer `Toast` over `Snackbar` for plain text feedback** (same look, less setup); use `Snackbar` when you need a custom background/corner radius or an **action button**.

```csharp
using CommunityToolkit.Maui.Alerts;

// Plain text (no action button)
await Snackbar.Make("Your changes have been saved")
              .Show(CancellationToken.None);

// With an action button
await Snackbar.Make("Item deleted",
                    action: () => { /* undo action */ },
                    actionButtonText: "Undo",
                    duration: TimeSpan.FromSeconds(5))
              .Show(CancellationToken.None);

// Custom appearance
await Snackbar.Make("Payment failed",
                    duration: TimeSpan.FromSeconds(5),
                    visualOptions: new SnackbarOptions
                    {
                        BackgroundColor = Colors.Red,
                        TextColor = Colors.White,
                        CornerRadius = new CornerRadius(10)
                    })
              .Show(CancellationToken.None);

// Anchored to a specific view
await myVisualElement.DisplaySnackbar("Snackbar anchored to a view");
```

### 8.1 Windows setup (required for Snackbar/Toast)

On **Windows** the snackbar uses a native toast notification. If you support Windows:

1. Enable it in `MauiProgram.cs`:

```csharp
builder.UseMauiCommunityToolkit(options =>
{
    options.SetShouldEnableSnackbarOnWindows(true);
});
```

2. Add toast-notification registration to `Platforms\Windows\Package.appxmanifest`:
   - In the opening `<Package>` tag, add the namespaces `com` and `desktop` and extend `IgnorableNamespaces` to `uap rescap com desktop`:

```xml
<Package
    xmlns:com="http://schemas.microsoft.com/appx/manifest/com/windows10"
    xmlns:desktop="http://schemas.microsoft.com/appx/manifest/desktop/windows10"
    IgnorableNamespaces="uap rescap com desktop">
```

   - Inside each `<Application>` tag, add these extensions (replace `YourProject` with your actual project name):

```xml
<Extensions>
    <desktop:Extension Category="windows.toastNotificationActivation">
        <desktop:ToastNotificationActivation ToastActivatorCLSID="6e919706-2634-4d97-a93c-2213b2acc334" />
    </desktop:Extension>
    <com:Extension Category="windows.comServer">
        <com:ComServer>
            <com:ExeServer Executable="YourProject\YourProject.exe"
                           DisplayName="$targetnametoken$"
                           Arguments="----AppNotificationActivated:">
                <com:Class Id="6e919706-2634-4d97-a93c-2213b2acc334" />
            </com:ExeServer>
        </com:ComServer>
    </com:Extension>
</Extensions>
```

> **Note:** the TestPopups project uses `WindowsPackageType=None` (unpackaged), which changes how toast activation is handled. Verify snackbar behavior on Windows after applying the manifest changes; the unpackaged app may require additional steps for the toast activator CLSID.

On **Android** and **iOS/Mac Catalyst** no setup is required.

### 8.2 Notes

- Only **one snackbar at a time**: showing a new one dismisses the current one.
- Events: `Snackbar.Shown`, `Snackbar.Dismissed`, `Snackbar.IsShown`.
- On Windows the snackbar **cannot** be anchored to a `VisualElement`; it always shows as a native toast.

## 9. Customizing

### 9.1 App-wide popup defaults

Override defaults for **every** popup in the app when initializing the toolkit:

```csharp
builder.UseMauiCommunityToolkit(options =>
{
    // Defaults for the Popup view itself (positioning, margin, padding, background, dismiss behavior)
    options.SetPopupDefaults(new DefaultPopupSettings
    {
        CanBeDismissedByTappingOutsideOfPopup = true,
        BackgroundColor = Colors.White,
        HorizontalOptions = LayoutOptions.Center,
        VerticalOptions = LayoutOptions.Center,
        Margin = 32,
        Padding = 16
    });

    // Defaults for PopupOptions applied on every ShowPopup call
    options.SetPopupOptionsDefaults(new DefaultPopupOptionsSettings
    {
        CanBeDismissedByTappingOutsideOfPopup = true,
        PageOverlayColor = Color.FromArgb("#B3000000"),
        Shape = new RoundRectangle { CornerRadius = 16 },
        Shadow = null
    });
});
```

Values set here can still be overridden per call by passing a `PopupOptions` instance.

### 9.2 Styling the popup in XAML

The `Popup` root exposes the same layout properties as any `View`. Style it directly in XAML:

```xml
<toolkit:Popup xmlns="http://schemas.microsoft.com/dotnet/2021/maui"
               xmlns:x="http://schemas.microsoft.com/winfx/2009/xaml"
               xmlns:toolkit="http://schemas.microsoft.com/dotnet/2022/maui/toolkit"
               x:Class="MyApp.Views.MyPopup"
               BackgroundColor="White"
               HorizontalOptions="Center"
               VerticalOptions="Center">

    <VerticalStackLayout Padding="24" WidthRequest="300" Spacing="15">
        <Label Text="Title" FontAttributes="Bold" HorizontalOptions="Center" />
        <Label Text="{Binding Message}" HorizontalOptions="Center" />
        <Button Text="Close" Command="{Binding ClosePopupCommand}" />
    </VerticalStackLayout>
</toolkit:Popup>
```

Use standard MAUI XAML inside the popup: resources, styles, data templates, behaviors, converters — anything that works on a regular `ContentView`.

> **Note:** `Shape` is not a property of the `Popup` view (XAML `toolkit:Popup.Shape` does not compile). Set the border via `PopupOptions.Shape` per call or app-wide with `SetPopupOptionsDefaults` (Sections 7/9.1).

> **Default background & text color:** if you set neither a background nor text colors, the popup and its content fall back to theme defaults. On some themes the default popup background and the default `Label` text color are both light/white, which can render white-on-white (invisible) text. If you want a guaranteed look, set `BackgroundColor` on the popup root and explicit `TextColor` values on your `Label`s (or drive both from `DefaultPopupSettings`/`DefaultPopupOptionsSettings`, Sections 7/9.1).

### 9.3 Positioning

Control position with `HorizontalOptions` / `VerticalOptions` on the popup root:

| Desired position | XAML |
|---|---|
| Center (default) | `HorizontalOptions="Center" VerticalOptions="Center"` |
| Top center | `HorizontalOptions="Center" VerticalOptions="Start"` |
| Bottom (sheet-like) | `HorizontalOptions="Fill" VerticalOptions="End"` |
| Corners/edges | combine `Start`/`Center`/`End` per axis |

### 9.4 Lifecycle & events

A popup is displayed inside a `PopupPage` shown modally. The calling page receives `OnNavigatingFrom`/`OnDisappearing`/`OnNavigatedFrom` when the popup opens, and `OnAppearing`/`OnNavigatedTo` when it closes. Distinguish popup-driven navigation with:

```csharp
protected override void OnNavigatedTo(NavigatedToEventArgs args)
{
    base.OnNavigatedTo(args);
    if (args.WasPreviousPageACommunityToolkitPopupPage())
    {
        // The popup was just dismissed
    }
}

protected override void OnNavigatingFrom(NavigatingFromEventArgs args)
{
    base.OnNavigatingFrom(args);
    if (args.IsDestinationPageACommunityToolkitPopupPage())
    {
        // A popup is about to open
    }
}
```

The `Popup` class also exposes `Opened` and `Closed` events, useful for one-shot setup/teardown in the popup's code-behind. Prefer `Opened` (not the constructor) for async load-on-open: the popup's visual tree is ready when `Opened` fires, so bindings and layout are stable.

```csharp
public MyPopup(MyPopupViewModel viewModel)
{
    InitializeComponent();
    BindingContext = viewModel;
    Opened += async (_, _) => await viewModel.LoadCommand.ExecuteAsync(null); // async load-on-open
    Closed += (_, _) => { /* cleanup */ };
}
```

### 9.5 Pitfalls & tips

- **Prefer DI over `new`.** The DI + `IPopupService` pattern (Section 3) is the recommended default for custom, reusable popups. Hand-instantiating with `new` + `ShowPopupAsync`/`ShowPopup` is **not the preferred approach**, but it is acceptable for stateless, parameterized popups (Sections 2 and 6) where a ViewModel adds no value. Avoid `new` when the popup has real logic — give it a ViewModel and register the pair instead.
- **Always check `WasDismissedByTappingOutsideOfPopup`** before reading `IPopupResult.Result`; when `true`, `Result` is `null`/`default`.
- **`PopupOptions` can be cached/reused** if several popups share the same configuration, to avoid repeated allocations.
- **`CanBeDismissedByTappingOutsideOfPopup = false`** is the right choice for mandatory confirmations (deletes, destructive actions). On Android it also disables the hardware back button for that popup.
- **`CancellationToken` on `ShowPopupAsync`** cancels the *wait* for the result; it does **not** close the popup.
- **Multiple stacked popups**: `ClosePopupAsync` closes the most recently opened popup.
- **`PopupBlockedException`**: a modal page open on top of the popup blocks closing it. Pop the modal first.
- **Shell routes for the popup**: not needed. The toolkit registers a temporary route internally when using `Shell.Current`; do not register popup views as Shell pages.
- **`OnNavigatingFrom` reliability**: on some MAUI versions `OnNavigatingFrom` does not fire correctly for popup navigation (known upstream issue). Prefer `OnNavigatedTo` + `WasPreviousPageACommunityToolkitPopupPage()` to detect popup dismissal.

## 10. Workflow

1. Confirm the task matches the scenarios above (popup or snackbar in a .NET MAUI app).
2. Verify the target project references **CommunityToolkit.Maui** and calls `UseMauiCommunityToolkit()`. Add them if missing (except for Section 1, which needs no package).
3. Pick the pattern from the [Quick decision guide](#quick-decision-guide).
4. Copy the matching pattern's code and adapt class/namespace names to the target project.
5. Register the popup where the app's DI is configured (`MauiProgram.CreateMauiApp()` or a DI extension method) if the pattern requires DI (Sections 3–5).
6. Apply [Options](#7-options) / [Customizing](#9-customizing) as needed.
7. Verify the build; report any blockers (missing package, missing Shell, platform-specific snackbar setup).

## References

- Official Toolkit Popup docs: https://learn.microsoft.com/en-us/dotnet/communitytoolkit/maui/views/popup
- Popup result (`Popup<T>`): https://learn.microsoft.com/en-us/dotnet/communitytoolkit/maui/views/popup/popup-result
- PopupOptions: https://learn.microsoft.com/en-us/dotnet/communitytoolkit/maui/views/popup/popup-options
- Snackbar: https://learn.microsoft.com/en-us/dotnet/communitytoolkit/maui/alerts/snackbar
- Toast: https://learn.microsoft.com/en-us/dotnet/communitytoolkit/maui/alerts/toast
