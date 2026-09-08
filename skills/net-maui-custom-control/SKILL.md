---
name: net-maui-custom-control
description: Use this skill when designing or implementing a custom control in .NET MAUI. It covers when a custom control is needed at all, how to choose the base class by semantic role (Button, Entry, Grid/layout, ContentView), the XAML control pattern (x:DataType, self-reference, ContentPresenter), BindableProperty, styling/visual states, and when to defer to SkiaSharp.
---

# .NET MAUI Custom Controls

Standard design and implementation patterns for **custom controls** in .NET MAUI apps. The goal is to pick the **simplest appropriate base class** and implement it cleanly, using an existing MAUI control whenever one already fits.

This skill contains the full instructions. Follow them in order: first confirm a custom control is actually needed, then use the [quick decision guide](#quick-decision-guide) to pick the base class, then build it with the [XAML control pattern](#3-the-xaml-control-pattern) and [implementation pattern](#4-implementation-pattern).

## When to use

- The task asks to **build, extend, or restyle a custom control** (a new `Button`/`Entry`-like control, a custom layout, a reusable composite view) in a .NET MAUI app.
- The task asks **which base class** a new control should derive from (`Button`, `Entry`, `Grid`, `ContentView`, ...).
- The task asks whether a UI element **needs a custom control at all**, or whether an existing control + style / behavior / animation is enough.
- The task asks how to expose **`BindableProperty`, commands, visual states, or a `ControlTemplate`** on a custom control.

> **Out of scope:** fundamental custom 2D drawing (charts, waveforms, diagrams, particle effects, shader effects) — defer to the dedicated **SkiaSharp** skill (see [Section 6](#6-custom-rendering-skia)).

## Prerequisites

- A .NET MAUI app that already references `Microsoft.Maui.Controls` (a fresh MAUI 10 template does by default). Custom controls built with XAML `ControlTemplate` and `BindableProperty` need **no extra NuGet packages**.
- **Source-generated XAML for custom controls:** set `<MauiXamlInflator>SourceGen</MauiXamlInflator>` in the app project. It enables compile-time checks for `x:DataType`/self-referencing bindings in control XAML, where the binding `Source` is the control itself.
- **SourceGen does not parse `Style` content in `App.xaml` or in new standalone dictionary files.** With `MauiXamlInflator=SourceGen` in force, adding inline `<Style>` definitions to `App.xaml` (or creating a new `ResourceDictionary` file full of `Style` elements) breaks the build with `MAUIG1001: "The method or operation is not implemented."` Keep styles in the template's existing `Resources/Styles/Styles.xaml` (which builds), or per-file opt out with `<MauiXaml Update="MyStyles.xaml" Inflator="Runtime" />`. **Caveat:** a runtime-inflated dictionary does not resolve `{DynamicResource}` on Windows at load time (it can throw "resource not present"), so prefer concrete values or keep the file on SourceGen.
- Custom **2D drawing** (only) additionally requires `SkiaSharp` + `SkiaSharp.Views.Maui`. This is handled by the SkiaSharp skill, not this one.

## Quick decision guide

Pick the **simplest** approach that satisfies the requirement:

| Scenario | Approach |
|---|---|
| Informational or interactive UI that an existing control already does | [Existing control + config / style / behavior / visual state](#1-when-do-you-actually-need-a-custom-control) |
| A specialized version of a `Button` (extra API, validation, domain behavior) | [`Button`-derived control](#2-choose-the-base-class-by-semantic-role) |
| A specialized version of `Entry` / `Editor` / `Picker` / `Switch` / `Slider` | [Derived from that control](#2-choose-the-base-class-by-semantic-role) |
| A fundamentally reusable **layout/container** with no better semantic base | [Layout-based control](#2-choose-the-base-class-by-semantic-role) |
| A reusable **labeled form field** (label + input + error row) built on an existing input | [Layout-based composite](#2-choose-the-base-class-by-semantic-role) with a small `Value` / `LabelText` / `Error` API |
| A reusable **composite/content wrapper** with a small API | [`ContentView`-based control](#2-choose-the-base-class-by-semantic-role) |
| Custom 2D drawing (chart, waveform, diagram, particles) | [SkiaSharp skill](#6-custom-rendering-skia) |

The single rule that drives every choice:

> **Choose the base class primarily by the semantic role of the control, not by its internal visual layout.**

## 1. When do you actually need a custom control?

Before creating a new control, check whether the requirement can be solved with an existing MAUI control. Prefer, in this order:

1. Existing control configuration
2. Styling
3. Visual states
4. Behaviors
5. Animations
6. Value converters / bindings
7. Only then: a custom control

Examples:

- Button with an icon → existing `Button`
- Button with a press animation → existing `Button` + animation/behavior
- Entry with custom styling → existing `Entry` + style
- Different visual appearance for the disabled state → existing control + `VisualStateManager`

Do not create a custom control merely to wrap a few properties or to reproduce functionality that MAUI already provides.

## 2. Choose the base class by semantic role

When a custom control is actually needed, ask: **what kind of control is this conceptually?**

- **Specialized version of an existing control → inherit from that control.** A navigation button might internally be text + chevron + spacing + animation; it is still semantically a **Button** (`NavigationButton : Button`, not `: Grid`). The same applies to `Entry`, `Editor`, `Picker`, `Switch`, `Slider`, and friends. A control that is semantically a slider or button should not be re-implemented from raw gestures: that silently loses keyboard interaction, screen-reader support, pressed/focus states, and platform behavior.
- **Fundamentally a reusable layout/container, no better semantic base → inherit from the layout that matches its structure:** `Grid`, `HorizontalStackLayout`/`VerticalStackLayout`, `FlexLayout`, `AbsoluteLayout`, `Border` (e.g. `Timeline : Grid`). This also covers **labeled form-field composites** (label + input + error row): they are `Grid`-based layouts around an existing `Entry`/`Switch`/`Picker`, exposing a small `Value` / `LabelText` / `Error` API instead of letting consumers wire the inner parts.
- **Reusable composite/content wrapper with a small API → `ContentView`.** Do not use `ContentView` as a default base for every custom control.

The visual structure (`Grid`, `Border`, `Label`s, custom drawing) is a **separate decision** from the base class: it is expressed in the control's XAML or a `ControlTemplate`, not in the inheritance hierarchy.

Do not replace a semantic control with a tappable layout (`Grid` + `TapGestureRecognizer`): that loses command support, pressed state, focus, keyboard interaction, accessibility/automation semantics, and platform-specific behavior.

## 3. The XAML control pattern

Most custom controls are built as a **partial class + XAML file**, where the XAML root element **is** the control's base type (or the control itself). The control class owns the file; the XAML is its internal visual tree.

### Conventions (apply to every control)

1. **Root element = the base class.** `<Grid>` for a `Grid`-derived control, `<Border>` for a `Border`-derived control, `<ContentView>` for a `ContentView`-derived control — so the code-behind `InitializeComponent()` wires the tree into the control itself.
2. **`x:DataType` is mandatory** on the root, set to the control's own type — e.g. `x:DataType="cv:FormEntry"`. It makes self-referencing bindings compile-time checked (with `<MauiXamlInflator>SourceGen</MauiXamlInflator>`), including nullable and type mismatches.
3. **One name for the root element: `x:Name="This"`.** Every control in the app uses this exact name, so the self-reference binding is always the same:

   ```xml
   {Binding LabelText, Source={x:Reference This}}
   ```

4. **`ControlTemplate` (instead of the direct tree) when the control should expose a default visual that consumers can override** with a style (`Setter Property="Template"`), or when the control hosts user-provided content via `ContentPresenter`. Two hard limits:
    - **Only `ContentView`-derived controls can take a default `ControlTemplate` in this pattern** (via `<ContentView.ControlTemplate>` in the XAML). `Button`, `Entry`, and the layout/border bases have **no `Template` property** — you cannot assign one. For those, keep the base `Text`/`TextColor` (simplest) or wrap the visual in a `Grid`/`Border` in the consuming page.
    - **Inside a `ControlTemplate` you may only use `TemplateBinding` and `{RelativeSource TemplatedParent}`** — the `{x:Reference}` / arbitrary `{RelativeSource}` self-reference pattern from convention 3 is only for the partial-class tree and will not parse inside a template.
5. **`ContentPresenter` — decide per control whether it accepts user content.**
   - Control derives from `ContentView`/`ContentPage` → it already has `Content`; a `ContentPresenter` (usually the last part of the template) presents it. Mark the class `[ContentProperty(nameof(Content))]` so XAML can pass content inline. **Never re-bind that presenter to the control's own `Content`** (e.g. `Content="{Binding Content, Source={x:Reference This}}"`) — in a partial-class tree the `Content` *is* the tree that contains the presenter, so the binding is circular and hangs in `GetMergedResources`. Leave the presenter unbound (it presents `Content` automatically), or move the visual into a `ControlTemplate` where the presenter is unbound and the rest binds via `TemplatedParent`.
   - Control derives from `Grid`/`Border`/`SwipeView` or similar → it has **no** `Content` property. Either (a) do not accept user content and expose a small property API instead, or (b) add a dedicated `[ContentProperty]`-backed `View` property that the XAML binds to. A `ContentPresenter` alone does not create a `Content` property — on a non-`ContentView` base it will always render empty.
   - Do not reach into internal containers (`Children.Insert(0, ...)`) as the public way to set content; that is implementation leaking.
6. **Theme-aware XAML:** use `DynamicResource`/`AppThemeBinding` for colors — never hard-coded white/black in control XAML, or the control breaks on theme switch.

### Shape of a control (partial-class XAML)

```xml
<Grid xmlns="http://schemas.microsoft.com/dotnet/2021/maui"
      xmlns:x="http://schemas.microsoft.com/winfx/2009/xaml"
      xmlns:cv="clr-namespace:MyApp.Controls"
      x:Class="MyApp.Controls.FormEntry"
      x:Name="This"
      x:DataType="cv:FormEntry">
    <Label Text="{Binding LabelText, Source={x:Reference This}}" />
    <Entry x:Name="EntryControl"
           Text="{Binding Value, Source={x:Reference This}}" />
</Grid>
```

```csharp
public partial class FormEntry : Grid
{
    public FormEntry() => InitializeComponent();

    public static readonly BindableProperty ValueProperty = BindableProperty.Create(
        nameof(Value), typeof(string), typeof(FormEntry), default(string),
        BindingMode.TwoWay);

    public string Value
    {
        get => (string)GetValue(ValueProperty);
        set => SetValue(ValueProperty, value);
    }
}
```

The XAML-vs-C# choice is independent of the base class: prefer XAML for declarative, relatively static visual trees; prefer C# for dynamic, data-generated, or algorithmic structure.

### Shape of a `ContentView` control (ControlTemplate)

When a `ContentView`-derived control needs a fixed header/chrome **plus** a user-provided `Content`, the clean form is a default `ControlTemplate` (which `ContentView` supports, unlike `Button`/`Entry`). The `ContentPresenter` is left unbound so it presents `Content` automatically; everything else binds to the control via `TemplatedParent`.

```xml
<ContentView xmlns="http://schemas.microsoft.com/dotnet/2021/maui"
             xmlns:x="http://schemas.microsoft.com/winfx/2009/xaml"
             xmlns:cv="clr-namespace:MyApp.Controls"
             x:Class="MyApp.Controls.SectionCard"
             x:Name="This"
             x:DataType="cv:SectionCard"
             Padding="12">
    <ContentView.ControlTemplate>
        <ControlTemplate>
            <Grid RowDefinitions="Auto,*">
                <!-- Header: binds to the control itself via TemplatedParent. -->
                <Grid Grid.Row="0" ColumnDefinitions="*,Auto" Margin="0,0,0,8">
                    <Label Text="{Binding Title, Source={RelativeSource TemplatedParent}}"
                           FontAttributes="Bold" />
                    <Button Grid.Column="1" Text="✎"
                            Command="{Binding EditCommand, Source={RelativeSource TemplatedParent}}" />
                </Grid>
                <!-- Presents the user Content automatically (NOT re-bound). -->
                <ContentPresenter Grid.Row="1" />
            </Grid>
        </ControlTemplate>
    </ContentView.ControlTemplate>
</ContentView>
```

```csharp
[ContentProperty(nameof(Content))]
public partial class SectionCard : ContentView
{
    public SectionCard() => InitializeComponent();

    public static readonly BindableProperty TitleProperty = BindableProperty.Create(
        nameof(Title), typeof(string), typeof(SectionCard), default(string));
    public string Title
    {
        get => (string)GetValue(TitleProperty);
        set => SetValue(TitleProperty, value);
    }

    public static readonly BindableProperty EditCommandProperty = BindableProperty.Create(
        nameof(EditCommand), typeof(ICommand), typeof(SectionCard), null);
    public ICommand EditCommand
    {
        get => (ICommand)GetValue(EditCommandProperty);
        set => SetValue(EditCommandProperty, value);
    }
}
```

Usage — inline content flows into `Content` via `[ContentProperty]`:

```xml
<cv:SectionCard Title="Details">
    <Label Text="Body content" />
</cv:SectionCard>
```

## 4. Implementation pattern

The general shape of the code-behind — fill it in for the control at hand:

```csharp
public class MyControl : <semantic base>   // or : Grid / : ContentView
{
    public MyControl()
    {
        // InitializeComponent(), set a default ControlTemplate (ContentView only),
        // or build the tree in code.
    }

    // One BindableProperty per meaningful public value; keep the API small.
    public static readonly BindableProperty TitleProperty =
        BindableProperty.Create(nameof(Title), typeof(string), typeof(MyControl), default(string));

    // Current propertyChanged signature (4 parameters) — the 3-parameter overload is obsolete.
    public static readonly BindableProperty DirectionProperty =
        BindableProperty.Create(
            nameof(Direction),
            typeof(NavigationDirection),
            typeof(MyControl),
            NavigationDirection.Forward,
            propertyChanged: OnDirectionChanged);

    static void OnDirectionChanged(BindableObject sender, object oldValue, object newValue)
    {
        // sender is the control instance.
    }

    public string Title
    {
        get => (string)GetValue(TitleProperty);
        set => SetValue(TitleProperty, value);
    }
}
```

> **Do not write a static constructor that calls `DefaultStyleKeyProperty.OverrideMetadata(...)`.** `DefaultStyleKeyProperty` and `FrameworkPropertyMetadata` are **not public API in MAUI 10** — that call does not compile (`CS0103`/`CS0246`) on `Button`, `Entry`, `Grid`, or `ContentView`. Custom-control style/template resolution is opt-in via the style key conventions and the `ControlTemplate` you assign (Section 3), not via a metadata override.

> **A `propertyChanged` does not fire when XAML sets the property to its default value.** If a dependent visual is initialized from a property in its `propertyChanged`, and XAML sets that property to the same value as the `BindableProperty` default, the handler never runs and the visual stays uninitialized. Initialize dependent visuals in the constructor / `OnApplyTemplate` (or after the first layout) as well, not only in `propertyChanged`.

- **Button/Entry-derived:** keep the base behavior (`Command`, `CommandParameter`, text, keyboard, focus, accessibility) and add the extra API on top. **These bases have no `Template` property, so you cannot give them a default `ControlTemplate`.** For the custom visual, either (a) keep the base `Text`/`TextColor` and drive them from your new properties (a navigation button appends a chevron glyph to `Text`; a glyph icon button sets `Text` to the glyph and `TextColor` from a `GlyphColor` property), or (b) wrap the control in a `Grid`/`Border` in the consuming page. On Windows in particular `Button` renders its own WinUI visual, so only properties the base exposes (`Text`, `TextColor`, `BackgroundColor`, ...) will show — `Text` is the reliable lever.
- **Layout-based:** own the internal visual tree; expose a small data API (e.g. `ItemsSource`) instead of letting consumers manipulate `Children`.
- **ContentView:** set `Content` (or template it via `ContentPresenter`) and expose the small API around it.
- **`BindableProperty`** for each meaningful public value — needed for XAML, data binding, styles, triggers, animations, and templates. Keep the public API small and intentional; do not expose implementation details.
- **Self-contained:** consumers interact with the public API, never with the internal visual tree.
- **Styling / visual states / animation:** prefer MAUI styling, `VisualStateManager`, `DynamicResource`, and templates over hard-coding visual behavior in the control. Animation alone does not justify a new base class.
- **Accessibility:** composite controls should set `SemanticProperties` (description, role) so screen readers treat them as one control; a hand-rolled slider/button loses keyboard and screen-reader support it would get from the semantic base.

## 5. Pitfalls

- **Don't create a custom control unnecessarily.** Check existing control + config / style / visual state / behavior / animation first.
- **Don't choose `Grid` just because the visual design uses a Grid**, and don't replace a `Button` with a tappable `Grid` just because it is easier to style. Base the control on its semantic role.
- **Don't use `ContentView` as a default base class.**
- **Match the `typeof(...)` argument of `BindableProperty.Create` to the declaring type.** Copy-paste between controls (e.g. registering `Command` with `typeof(CalcMaterialButton)` on `GlyphOnlyButton`) compiles, but metadata, styles, and defaults hang off the wrong type.
- **Don't read resources before the app/element is in the resource chain — and remember the indexer throws, it does not return null.** `Resources["key"]` (and `Application.Current.Resources["key"]`) **throws** on a missing key, so `(Color?)Resources["Primary"] ?? fallback` does *not* save you — the `??` is never reached. Two traps: (1) an element's own `Resources` is **empty until the element joins the resource chain**, so it will not see `Primary`/`Secondary`/etc. that live in the app dictionary; (2) in a **constructor** or a `propertyChanged` that fires during **XAML inflation**, the chain is not ready, so the lookup throws and the app crashes at startup (or the window never appears). Read app resources only after the element is live (`HandlerChanged`, `OnAppearing`, or a user-initiated event), read them **null-safely** (wrap the indexer in `try/catch` and fall back), or prefer `DynamicResource` in XAML. A small helper keeps this DRY:

  ```csharp
  static Color SafeColor(string key, Color fallback)
  {
      try { return Application.Current?.Resources[key] is Color c ? c : fallback; }
      catch { return fallback; }
  }
  ```
- **Don't call `GetTemplateChild` in the constructor** — the template is not applied yet; do it after `OnApplyTemplate` / in the `propertyChanged` of the relevant property.
- **Know what a base can actually be styled with.** `Entry` has **no `Padding`** property (a style setter for it fails at runtime with "Can't resolve PaddingProperty on Entry"). `Entry` exposes `BorderColor`/`BorderWidth`/`CornerRadius` in reflection, but the XAML compiler rejects `BorderColor` on `Entry` in some MAUI versions/TFMs — treat those as unreliable. For an "outline" `Entry`, wrap it in a `Border` in the consuming page and style the `Border`. Check a control's real settable surface before writing a style for it.
- **Don't assume `Color.FromArgb(r, g, b)` compiles.** In MAUI 10 the argb overload needs four arguments (with alpha); the three-arg form fails with "No overload for method 'FromArgb' takes 3/4 arguments". Use `Color.Parse("#RRGGBB")` (or the explicit 4-arg form) instead.
- **Don't put `Style` definitions in `App.xaml` or new standalone dictionary files while SourceGen is on** (see Prerequisites). It breaks the build with `MAUIG1001`; keep styles in the template's `Styles.xaml` or per-file opt out with `Inflator="Runtime"` (and avoid `DynamicResource` in a runtime-inflated dictionary on Windows).
- **A circular `Border` shape is XAML-declared with a fixed radius — it is not runtime-driveable.** `Microsoft.Maui.Graphics` exposes no public shape class (no `RoundShape`/`IShape` concrete type) and `Border.StrokeShapeProperty` has no accessible `TypeConverter` to invoke from code, so the only way to get a circle is the XAML string form `StrokeShape="RoundRectangle <radius>"` (radius = diameter/2). A `Diameter`/`Size` bindable property can drive the border's width/height, but it cannot re-shape the stroke: if a consumer sets `Diameter="60"`, the border becomes 60×60 but the radius stays at the XAML literal, so it renders as a rounded rectangle, not a circle. If you need a truly runtime-resizable circle, draw it (e.g. a `Path` with a `CircleGeometry`, or defer to the SkiaSharp skill).
- **In code, build `Grid` row/column definitions by adding `RowDefinition`/`ColumnDefinition` instances — the XAML string shorthand has no C# constructor.** `new RowDefinitions("Auto, Auto")` and `new ColumnDefinitions("18, *")` do not compile; the string-parsing form is a XAML type-converter path only. The code idiom is:
  ```csharp
  grid.RowDefinitions.Add(new RowDefinition(GridLength.Auto));
  grid.RowDefinitions.Add(new RowDefinition(new GridLength(18, GridUnitType.Absolute)));
  grid.ColumnDefinitions.Add(new ColumnDefinition(GridLength.Star));
  ```
  This matters most for the "prefer C# for dynamic, data-generated structure" case (e.g. a `Timeline` that builds one row per data item).
- **Don't introduce public methods consumers must call** (e.g. `UpdateGui()` after layout) and don't expose content APIs that break on repeated use. If the consumer has to call something to make the control work, the control is not self-contained.
- **Don't introduce SkiaSharp for normal UI**, and don't assume animation requires `SKGLView`.
- **Don't over-engineer one-off UI.** A custom control should provide meaningful reuse or encapsulate meaningful behavior.
- **Keep accessibility and platform semantics intact.** A custom control should behave like the thing it represents.

## 6. Custom rendering (Skia)

Prefer normal MAUI controls and layouts whenever they are sufficient. Use a custom rendering solution only when the visual is fundamentally based on **drawing** (charts, graphs, waveforms, diagrams, particle effects, highly graphical backgrounds):

```text
Normal UI           -> MAUI controls/layouts (this skill)
Custom 2D rendering -> SkiaSharp skill
```

Do not duplicate detailed SkiaSharp implementation guidance here — defer to the dedicated **SkiaSharp** skill. Two notes on the rendering surface (also detailed there):

- Do not use `SKGLView` merely because something is animated. An animated wave can often be implemented with `SKCanvasView`.
- `SKGLView` becomes relevant only for a concrete GPU/OpenGL-oriented need: shader-based effects, large numbers of graphical elements, or a measured rendering/performance requirement.

Default to the simpler rendering approach.

## 7. Workflow

1. Apply [Section 1](#1-when-do-you-actually-need-a-custom-control): if an existing control + style/behavior/animation suffices, stop there — do not create a custom control.
2. Pick the base class from the [quick decision guide](#quick-decision-guide) by **semantic role**, not internal layout.
3. Build with the [XAML control pattern](#3-the-xaml-control-pattern): root element = base class, `x:DataType` set to the control type, `x:Name="This"`, self-reference bindings; decide `ControlTemplate` + `ContentPresenter` vs direct tree.
4. Fill in the [implementation pattern](#4-implementation-pattern): one `BindableProperty` per meaningful public value (declaring type matches), keep the public API small; preserve commands, focus, and accessibility for semantic controls.
5. Use theme-aware resources in the control XAML; apply styling/visual states rather than hard-coding visual behavior.
6. If the visual is fundamentally custom 2D drawing, hand off to the **SkiaSharp** skill instead ([Section 6](#6-custom-rendering-skia)).
7. Verify the build; report any blockers.

## References

- .NET MAUI `ControlTemplate`: https://learn.microsoft.com/en-us/dotnet/maui/fundamentals/xaml/xaml-controls/control-templates
- .NET MAUI `BindableProperty`: https://learn.microsoft.com/en-us/dotnet/maui/fundamentals/data-binding/bindable-properties
- .NET MAUI `VisualStateManager`: https://learn.microsoft.com/en-us/dotnet/maui/fundamentals/xaml/xaml-controls/visual-states
- .NET MAUI `ContentView`: https://learn.microsoft.com/en-us/dotnet/maui/essentials/layout/contentview
- .NET MAUI custom controls with XAML: https://learn.microsoft.com/en-us/dotnet/maui/fundamentals/xaml/xaml-controls/custom-controls
- CommunityToolkit.Maui `SkiaSharp`: https://learn.microsoft.com/en-us/dotnet/communitytoolkit/maui/views/skias
