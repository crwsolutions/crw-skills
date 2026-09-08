---
name: net-maui-skiasharp
description: Use this skill when implementing custom 2D rendering in a .NET MAUI app with SkiaSharp 4.x. It covers SKCanvasView vs SKGLView (CPU and GPU paths), subclassing SKCanvasView (preferred) or wrapping it in a ContentView, coordinate systems (DIP vs pixels, fixed world + fit), BindableProperty-driven invalidation, animation loops, gesture handling, bundled-font loading, resource reuse, and SkiaSharp 4.x API rules.
---

# .NET MAUI SkiaSharp

Standard implementation patterns for **custom 2D rendering** in .NET MAUI apps, using **SkiaSharp 4.x** with `SkiaSharp.Views.Maui.Controls`. The goal is to render custom visuals correctly and efficiently without breaking MAUI layout, density scaling, or control semantics.

This skill contains the full instructions. Follow them in order: pick the rendering surface from the [quick decision guide](#quick-decision-guide), then implement with the [preferred pattern](#2-implementation-patterns).

The **`net-maui-custom-control`** skill decides the semantic architecture of a control (base class, `BindableProperty`, XAML pattern). This skill only covers the SkiaSharp rendering implementation inside such a control.

## When to use

- The task asks to draw **custom 2D graphics** in a .NET MAUI app: charts, graphs, waveforms, diagrams, timelines, particle effects, highly graphical backgrounds.
- The task asks how to add **`SKCanvasView`** (or `SKGLView`) to a MAUI app, or how to wrap it in a custom control.
- The task asks how to make a SkiaSharp visual **react to data** (`BindableProperty` → redraw), **handle input** (tap/drag/zoom), or **resize/re-density** correctly.
- The task is **troubleshooting** a SkiaSharp rendering or performance issue (blurry lines, wrong size, stale drawing, frame drops).

> **Out of scope:** normal UI (buttons, forms, cards, styled controls) — use MAUI controls + styling, or the **`net-maui-custom-control`** skill.

## Prerequisites

Add one NuGet package to the MAUI app project (it brings in the core SkiaSharp packages):

```xml
<PackageReference Include="SkiaSharp.Views.Maui.Controls" Version="4.*" />
```

> **Version note:** the 4.x API here is verified against **SkiaSharp 4.15x** (`4.*` resolved to 4.151.2). The MAUI views package is split into a small type-forward assembly plus a platform handler assembly, so the concrete `SKCanvasView`/`SKGLView` types and the paint-event args come from the workload's handler package — if a name in this skill stops resolving, check the installed SkiaSharp version before assuming the API changed shape.

- Do **not** add the old Xamarin.Forms SkiaSharp packages (`SkiaSharp.Views.Forms`) to a MAUI project.
- Initialize once in `MauiProgram.cs` with `UseSkiaSharp()`. It registers the `SKCanvasView` **and** `SKGLView` handlers plus the `SKImage`/`SKBitmap`/`SKPixmap` image-source services — no manual handler registration is needed:

  ```csharp
  using SkiaSharp.Views.Maui.Controls.Hosting; // UseSkiaSharp()

  builder.UseMauiApp<App>()
         .UseSkiaSharp();
  ```

- In XAML, use the namespace:

  ```xml
  xmlns:skia="clr-namespace:SkiaSharp.Views.Maui.Controls;assembly=SkiaSharp.Views.Maui.Controls"
  ```

- **Usings:** the MAUI-specific SkiaSharp types live in a second namespace. You need both:

  ```csharp
  using SkiaSharp;                  // SKCanvas, SKPaint, SKPath, SKFont, SKColor, ...
  using SkiaSharp.Views.Maui;       // SKPaintSurfaceEventArgs, SKTouchEventArgs, SKTouchAction
  using SkiaSharp.Views.Maui.Controls; // SKCanvasView, SKGLView
  ```

  Forgetting `SkiaSharp.Views.Maui` is the most common compile error: `SKPaintSurfaceEventArgs` and `SKTouchEventArgs` do **not** live in `SkiaSharp` or `SkiaSharp.Views.Maui.Controls`.

## Quick decision guide

| Scenario | Approach |
|---|---|
| Charts, diagrams, timelines, waveforms, particle effects, graphical backgrounds | `SKCanvasView` |
| Shader-based effects, GPU-oriented or measured-continuous rendering | `SKGLView` — after measuring `SKCanvasView` first |
| Smooth continuous animation (any platform) | `SKCanvasView` + `Animation.Commit` (Section 6) — keeps it a CPU canvas, smooth on all platforms |

> **Start with `SKCanvasView`.** For smooth, continuous animation, drive it with **`Animation.Commit`** (Section 6) — it runs a high-priority, display-synced loop and keeps the control a plain CPU canvas, so it's the right default on every platform (the plain `Dispatcher` timer is too coarse on Windows). Reserve `SKGLView` for a concrete GPU/OpenGL requirement (shaders, very large element counts, a measured CPU shortfall) — not merely because "GPU sounds faster" or because something is animated.

## 2. Implementation patterns

### Preferred: subclass `SKCanvasView` directly

When the control **is** the canvas — no wrapper chrome, no other child views — subclass `SKCanvasView` directly. A subclass reuses the existing `SKCanvasViewHandler`, which `.UseSkiaSharp()` already registered (see [Prerequisites](#prerequisites)), so **subclassing needs no handler code of its own**.

This is the simplest and most direct pattern: the control is the drawing surface, gestures and layout properties live on the same object, and `InvalidateSurface()` is called on `this`.

```csharp
public class AxisTicks : SKCanvasView
{
    private const float WorldW = 100, WorldH = 100;
    private const int MajorCount = 5;

    private readonly SKPaint _bgPaint;
    private readonly SKPaint _linePaint;
    private readonly SKPaint _labelPaint;
    private readonly SKFont _labelFont = new(SKTypeface.Default, 6);

    public AxisTicks()
    {
        _bgPaint = new SKPaint { Color = new SKColor(16, 18, 26), Style = SKPaintStyle.Fill };
        _linePaint = new SKPaint { Color = new SKColor(90, 110, 150), Style = SKPaintStyle.Stroke, StrokeWidth = 1f, IsAntialias = true };
        _labelPaint = new SKPaint { Color = new SKColor(180, 190, 210), Style = SKPaintStyle.Fill, IsAntialias = true };

        PaintSurface += OnPaintSurface;
    }

    void OnPaintSurface(object? sender, SKPaintSurfaceEventArgs e)
    {
        var canvas = e.Surface.Canvas;
        var info = e.Info;
        canvas.Clear(_bgPaint.Color);
        if (info.Width <= 0 || info.Height <= 0) return;

        // Fixed world + fit, in DIP space (scale the pixel canvas into DIPs first — see Section 5).
        float w = (float)Width, h = (float)Height;
        canvas.Scale(info.Width / w, info.Height / h);
        float s = Math.Min(w / WorldW, h / WorldH);
        float ox = (w - WorldW * s) / 2f, oy = (h - WorldH * s) / 2f;
        canvas.Translate(ox, oy);
        canvas.Scale(s);

        // Major + minor ticks along a 100-unit axis.
        for (int i = 0; i <= WorldW; i += 5)
        {
            bool major = i % (100 / MajorCount) == 0;
            float x = i;
            canvas.DrawLine(x, 88, x, major ? 80 : 84, _linePaint);
            if (major)
                canvas.DrawText(i.ToString(), x, 95, SKTextAlign.Center, _labelFont, _labelPaint);
        }
    }
}
```

**Key differences from the wrapper pattern:**

- `PaintSurface += OnPaintSurface` in the constructor (not on a private field).
- `InvalidateSurface()` on `this` (not `_canvas.InvalidateSurface()`).
- `GestureRecognizers.Add(...)` on `this`.
- `e.GetPosition(this)` for pointer position (not `e.GetPosition(_canvas)`).
- No `InputTransparent` to manage — the canvas is the view, so it receives input by default.

**Sizing in XAML:** `SKCanvasView` does not expose `HeightRequest`/`WidthRequest` as `BindableProperty` in the MAUI handler. Wrap the subclass in a `Border` (or `Frame`) to set a fixed size:

```xml
<Border HeightRequest="160" Padding="0" BackgroundColor="Transparent">
    <local:AxisTicks />
</Border>
```

### When the canvas is one of several views (wrapper)

Subclassing only works when the control *is* the canvas. If you need to wrap the canvas with other views (labels, buttons) or split interaction between the canvas and the owner, hold an `SKCanvasView` as a private field in a `ContentView`:

```csharp
_canvas = new SKCanvasView { InputTransparent = true }; // passive: let gestures pass to the owner
_canvas.PaintSurface += OnPaintSurface;
Content = _canvas;

// Gestures go on the ContentView, not the canvas.
GestureRecognizers.Add(new TapGestureRecognizer { Tapped = ... });
// Invalidate with _canvas.InvalidateSurface(); read _canvas in PaintSurface.
```

Set **`InputTransparent = true`** when the wrapper handles taps (otherwise the canvas swallows the gesture), or `false` when the canvas itself handles input via its own `GestureRecognizers` (use `e.GetPosition(_canvas)` then). Use the same XAML-control conventions as the `net-maui-custom-control` skill when the wrapper has chrome.

## 3. Gesture handling

`SKCanvasView` does **not** expose a reliable `Touch` event in the MAUI variant. The `SKTouchEventArgs`/`SKTouchAction` types exist in `SkiaSharp.Views.Maui` but the `Touch` event on `SKCanvasView` is not consistently raised. Use MAUI gesture recognizers instead.

### Tap

```csharp
// On a SKCanvasView subclass:
var tap = new TapGestureRecognizer();
tap.Tapped += (_, _) => { /* handle */ };
GestureRecognizers.Add(tap);

// On a ContentView wrapper (canvas is InputTransparent=true):
// Same, but add to the ContentView's GestureRecognizers.
```

### Pointer (press / move / release — drag, scrub, pan)

```csharp
// On a SKCanvasView subclass:
var pointer = new PointerGestureRecognizer();
pointer.PointerPressed += OnPointerPressed;
pointer.PointerMoved   += OnPointerMoved;
pointer.PointerReleased += OnPointerReleased;
GestureRecognizers.Add(pointer);

void OnPointerPressed(object? sender, PointerEventArgs e)
{
    var pos = e.GetPosition(this)!.Value;   // canvas-local coordinates
    // Convert to world coordinates if using fixed-world + fit:
    float worldX = ((float)pos.X - _offsetX) / _scale;
    float worldY = ((float)pos.Y - _offsetY) / _scale;
    // ...
}

void OnPointerMoved(object? sender, PointerEventArgs e)
{
    if (!_isDragging) return;
    var pos = e.GetPosition(this)!.Value;
    // ...
    InvalidateSurface();
}

void OnPointerReleased(object? sender, PointerEventArgs e)
{
    _isDragging = false;
    InvalidateSurface();
}
```

On a `ContentView` wrapper with the canvas handling input, set `InputTransparent = false` on the canvas and add the `PointerGestureRecognizer` to the **canvas's** `GestureRecognizers`, using `e.GetPosition(_canvas)`.

### Pinch / zoom

`PinchGestureRecognizer` works the same way: add it to the view's `GestureRecognizers`, read `e.Scale`, and apply it to your transform (multiply into `_scale`, recompute offsets, invalidate).

### Key rule

`e.GetPosition(view)` returns **canvas-local coordinates** (not page or screen), as a nullable `Microsoft.Maui.Graphics.Point?` (not `SKPoint`) — it is `null` only outside a valid gesture, so unwrap with `!.Value` (or `?.Value` with a guard). If you use a fixed-world + fit transform, convert with the inverse of the transform you applied in `OnPaintSurface` — note `PointerEventArgs` has no `GetCurrentPoint`, and cast the `double` components to `float` at the boundary:

```csharp
var pos = e.GetPosition(this)!.Value;                 // Microsoft.Maui.Graphics.Point (e.GetPosition returns Point?)
float wx = (float)((pos.X - _offsetX) / _scale);       // world (matches the e.Info-pixel transform)
float wy = (float)((pos.Y - _offsetY) / _scale);
```

## 4. SKGLView — GPU rendering

`SKGLView` is a separate view (not an `SKCanvasView` subclass) that renders on the GPU. In 4.x the render surface is handed to you on the paint event (`e.Surface`, already bound to the GPU context) — you do not create a surface from a `GRContext` yourself. Use it only after measuring `SKCanvasView` and finding a concrete shortfall (shaders, tens of thousands of elements, a measured frame-rate problem) — see the [quick decision guide](#quick-decision-guide).

`UseSkiaSharp()` already registers the `SKGLViewHandler`, so subclassing `SKGLView` needs no handler code.

```csharp
using SkiaSharp;
using SkiaSharp.Views.Maui;          // SKPaintGLSurfaceEventArgs
using SkiaSharp.Views.Maui.Controls; // SKGLView

public class GlSparkline : SKGLView
{
    private const float WorldW = 100, WorldH = 100;
    private const int SampleCount = 60;

    private readonly SKPaint _bgPaint;
    private readonly SKPaint _linePaint;
    private readonly SKPoint[] _points = new SKPoint[SampleCount];
    private float _phase;
    private DateTime _lastTick = DateTime.UtcNow;

    public GlSparkline()
    {
        _bgPaint = new SKPaint { Color = new SKColor(10, 14, 24), Style = SKPaintStyle.Fill };
        _linePaint = new SKPaint { Color = new SKColor(90, 220, 180), Style = SKPaintStyle.Stroke, StrokeWidth = 2f, IsAntialias = true };

        HasRenderLoop = true;   // continuous rendering: PaintSurface fires every frame
        PaintSurface += OnPaintSurface;
    }

    void OnPaintSurface(object? sender, SKPaintGLSurfaceEventArgs e)
    {
        // Advance state from wall-clock time — never use the render loop as the clock.
        var now = DateTime.UtcNow;
        _phase += (float)(now - _lastTick).TotalSeconds * 3f;
        _lastTick = now;

        // Use e.RawInfo: the true pixel size of the GL surface (no density scaling).
        var info = e.RawInfo;
        if (info.Width <= 0 || info.Height <= 0)
            return;

        // In SkiaSharp 4.x the args already provide a ready, context-bound surface —
        // draw directly on it. Do NOT call SKSurface.Create(...); e.GRContext does
        // not exist on SKPaintGLSurfaceEventArgs in 4.x (it is a compile error).
        var canvas = e.Surface.Canvas;
        canvas.Clear(_bgPaint.Color);

        // Same fixed-world + fit math as SKCanvasView (Section 5), in DIP space,
        // applied to the GL surface. e.RawInfo is the pixel size; Width/Height are DIPs.
        float w = (float)Width, h = (float)Height;
        canvas.Scale(info.Width / w, info.Height / h);   // pixels -> DIPs
        float s = Math.Min(w / WorldW, h / WorldH);
        canvas.Translate((w - WorldW * s) / 2f, (h - WorldH * s) / 2f);
        canvas.Scale(s);

        // A moving sparkline. SkiaSharp 4.x has no DrawLines — draw the segments
        // individually (or build an SKPathBuilder path and DrawPath once).
        for (int i = 0; i < SampleCount; i++)
        {
            float x = WorldW * i / (SampleCount - 1);
            float y = 50f + 25f * (float)Math.Sin(x * 0.12f + _phase);
            _points[i] = new SKPoint(x, y);
        }
        for (int i = 0; i < SampleCount - 1; i++)
            canvas.DrawLine(_points[i], _points[i + 1], _linePaint);
    }
}
```

Key differences from `SKCanvasView`:

- **`HasRenderLoop = true`** starts a continuous render loop: `PaintSurface` fires every frame on its own, so you don't call `InvalidateSurface()` to animate — the loop already redraws. Set it `false` for event-driven rendering and call `InvalidateSurface()` manually (same as `SKCanvasView`).
- **`SKCanvasView` has no `HasRenderLoop`.** Only `SKGLView` exposes it. If you want smooth, display-refresh-rate animation on a CPU canvas, use **`Animation.Commit`** (Section 6) — keep the control an `SKCanvasView` and drive it with MAUI's animation API. `SKGLView` is for when you additionally need the GPU (shaders, scale, measured CPU shortfall).
- **The handler is `SKPaintGLSurfaceEventArgs`**, which exposes `Surface`, `Info`, and `RawInfo` (notably **no `GRContext`** in 4.x). Use **`e.RawInfo`** for pixel dimensions on the GL surface.
- **Draw on `e.Surface.Canvas`.** The args already provide a ready, context-bound surface bound to the GPU, not a CPU bitmap. Do **not** call `SKSurface.Create(...)` — there is no `e.GRContext` to pass in 4.x.
- **Same fixed-world + fit transform as `SKCanvasView`.** Apply the exact §5 math — scale the pixel canvas into DIPs first (`canvas.Scale(info.Width / Width, info.Height / Height)`), then fit the world into the DIP box (`scale = Math.Min(w / WorldW, h / WorldH)`, centered `Translate` + `Scale`) — using **`e.RawInfo`** as the pixel size and `Width`/`Height` (DIPs) for the DIP box. The transform carries over verbatim from Section 5 — only the size source (`e.RawInfo`, pixels) and the canvas (`e.Surface.Canvas`) differ.
- **`EnableTouchEvents`** gates the `Touch` event; for gestures, use the same `TapGestureRecognizer` / `PointerGestureRecognizer` approach as `SKCanvasView` (add to `GestureRecognizers`).
- **Same sizing caveat:** wrap the view in a `Border` in XAML to set a fixed size.
- Everything else carries over: fixed-world + fit transform, `Save`/`Restore`, resource reuse, and the paint callback renders-only rule.

## 5. Rules for the paint callback

- **Render only.** Read current state, calculate geometry, draw. No business logic, no I/O, no state mutation (see [animation](#6-invalidation-state--animation)).
- **Guard against a zero-size surface.** `e.Info` can be `0` during initial layout; early-return after clearing so you never divide by zero:

  ```csharp
  if (info.Width <= 0 || info.Height <= 0) { canvas.Clear(); return; }
  ```

- **Size: use `e.Info.Width` / `e.Info.Height`** — the actual **physical-pixel** dimensions of the current surface. Never assume a fixed size, and don't derive them from `Width * Density` (that's where double-scaling bugs come from).

  > **`e.Info` is pixels, but input is DIPs — this is the classic high-DPI tap-mapping bug.** `e.Info` (and the `SKCanvasView` canvas) are in **physical pixels**, while `e.GetPosition(view)` (and `Width`/`Height`) are in **device-independent pixels (DIPs)**. They only match when the density is 1.0 (e.g. Windows at 100%), which is why a tap→world mapping can look *perfect on a laptop and land off by the density factor on a phone* (a tap at the corner spawns at ~1/2, 1/3, or 1/4 of the right spot). The rule: **pick one space for drawing AND for input inversion, and convert everything to it.** The cleanest is to draw in DIPs — scale the pixel canvas into DIPs first — so the transform and `GetPosition` agree.

- **Pick one coordinate system and convert at the boundary.** Two common choices:
  - **Minimal (DIP):** scale once so you can draw in MAUI device-independent units; `StrokeWidth = 2` then means 2 DIP everywhere. Good when the visual just fills its box and you don't map input.

    ```csharp
    canvas.Scale(info.Width / (float)Width, info.Height / (float)Height); // pixels -> DIPs
    // draw using DIP coordinates
    ```

  - **Fixed world + fit (recommended for diagrams/charts):** draw in a fixed logical space (e.g. 800×600), fit it preserving aspect ratio, and center it. **Scale into DIPs first**, then fit the world into the DIP box — and compute the inverse in that same DIP space so `GetPosition` (DIPs) maps back correctly:

    ```csharp
    const float WorldW = 800, WorldH = 600;
    float w = (float)Width, h = (float)Height;            // DIPs
    canvas.Scale(info.Width / w, info.Height / h);         // pixels -> DIPs
    _scale   = Math.Min(w / WorldW, h / WorldH);
    _offsetX = (w - WorldW * _scale) / 2f;
    _offsetY = (h - WorldH * _scale) / 2f;
    canvas.Translate(_offsetX, _offsetY);
    canvas.Scale(_scale);
    // draw in world coordinates

    // Inverse for hit-testing / pointer mapping. e.GetPosition returns DIPs,
    // which is the same space as _offsetX/_scale above, so this is exact:
    //   var p = e.GetPosition(this)!.Value;
    //   float wx = (float)((p.X - _offsetX) / _scale);
    //   float wy = (float)((p.Y - _offsetY) / _scale);
    ```

    **Do not skip the initial pixels→DIP scale** (i.e. do not fit the world directly into `e.Info` pixel space) unless you also scale the pointer into pixels before inverting — `px = p.X * info.Width / Width` (likewise `py`) — otherwise the mapping is off by the density factor on high-DPI devices. The DIP-space form above is the consistent one: it matches the §2 `AxisTicks` example, the §4 GL example, and keeps `GetPosition` (DIPs) in the same space as `_offsetX`/`_scale`.
  Apply any scale **exactly once** per paint; keep the transform in fields so event handlers can invert it. **Initialize those fields before the first paint** (`_scale = 1f`, `_offsetX = _offsetY = 0`, or a `_scale > 0` guard in the inverse) so a tap that arrives before the first `OnPaintSurface` cannot divide by zero — the gesture handler reads the fields that the paint callback populates, and on a cold start the paint may not have run yet.
- **Drawing order is the z-order.** Draw background → grid → data → labels → interaction overlays, in that order — a later draw covers an earlier one.
- **Keep drawing thin:** for anything non-trivial, delegate the actual drawing to static renderer helpers (e.g. `PitchRenderer.Draw(canvas, ...)`, `BallRenderer.DrawBall(canvas, x, y)`) so `OnPaintSurface` is just clear + transform + delegate. This keeps geometry reusable and easier to test.

## 6. Invalidation, state & animation

- **Redraw on data change:** call `InvalidateSurface()` from the `propertyChanged` of every `BindableProperty` that affects the visual. Avoid invalidating when nothing visually changed.
- **Immediate mode:** there is no retained scene graph — every invalidation re-renders the whole surface from current state. If only a visual property changed, keep cached geometry; recalculate geometry only when the data changes.
- **Animation:** keep state updates and rendering separate — the driver advances the state and calls `InvalidateSurface()`; the paint callback only renders whatever state it reads. There are two drivers, in order of preference:

  1. **`Animation.Commit` (recommended for smooth, continuous animation).** MAUI's own animation API runs a high-priority, display-synced loop (`ValueAnimator` on Android, `CADisplayLink` on iOS, a high-priority `DispatcherQueueTimer` on Windows) that fires its callback at roughly the display refresh rate. It keeps the control a plain CPU `SKCanvasView` subclass (no GL), so all your `SKPaint`/`SKPathBuilder`/`SKFont` code carries over, and it is the smoothest path on **every** platform — including Windows, where the plain `Dispatcher` timer is too coarse (below).
  2. **`Dispatcher` timer (simple, cross-platform, but coarse on Windows).** Good for event-driven, low-frequency, or low-precision visuals. On the MAUI **Windows** TFM it is backed by the WinUI `DispatcherQueueTimer`, which quantizes a 16ms period to roughly **20–40ms**, so continuous animation *looks stuttery* (CPU/memory are fine — the timer, not the renderer, is the bottleneck). On Android/iOS the same timer behaves fine.

  ### Recommended: `Animation.Commit`

  ```csharp
  using Microsoft.Maui.Controls; // Animation, Easing, IAnimatable

  // In the SKCanvasView subclass:
  public MyControl()
  {
      PaintSurface += OnPaintSurface;

      // Continuous, repeating animation (e.g. a radar sweep 0..360):
      new Animation(OnFrame, 0, 360)
          .Commit(this, "MySweep", rate: 60, length: 4000,
                  easing: Easing.Linear,
                  finished: (_, _) => { },     // required, can be a no-op
                  repeat: () => true);
  }

  void OnFrame(double value)
  {
      _angle = (float)value;   // value is the eased position in [start, end]
      InvalidateSurface();
  }
  ```

  - **`Commit` needs all seven args** — `rate`, `length` (ms), `easing`, `finished`, and `repeat` are all required on MAUI (older Xamarin.Forms examples that omit `rate`/`easing`/`finished` will not compile). `Commit` returns `void`; just call it.
  - **The callback receives the eased value in `[start, end]`**, not a raw timestamp. Derive your visual state from that value. For a *physics* simulation (particles, etc.), still integrate against a `Stopwatch` (`dt` between callbacks) so speed and decay are time-accurate; the commit loop is only the *trigger*.
  - **The value is monotonic in `[start, end]`** — for a back-and-forth visual (pulse, breathing), remap it before applying (e.g. `t = (1 - cos(2π·value)) / 2` for a smooth sine wave 0→1→0, or a triangle wave). A single linear `0..1` commit with `repeat: () => _running` is enough for a repeating pulse; the remap is what makes it go out *and back*.
  - **Control start/stop with the `repeat` delegate.** It is polled on each tick; return `false` to stop. For a toggleable animation, return a flag (`repeat: () => _running`), and re-`Commit` a fresh `Animation` when you turn it back on. For a one-shot that can be re-triggered (a tap burst), return a "still active" condition (`repeat: () => AnyAlive()`) and (re)`Commit` on each trigger.
  - **`repeat` must be pure — no side effects.** Do not call `Commit` *from inside* the `repeat` delegate; the commit loop may still be polling it, and that is not a supported re-entry pattern. For a stop flag (`_running`), set it directly in the toggle handler (it takes effect on the next tick), then `Commit` a fresh `Animation` from that same handler — *not* from inside `repeat`.
  - `View` implements `IAnimatable`, so `Commit(this, ...)` works on any `SKCanvasView`/`SKGLView` subclass.
  - **Never use the callback's cadence as the clock** — derive continuous motion from the eased value or a `Stopwatch`, not from frame counts (the cadence varies by device/refresh rate).
   - **Triggerable one-shot + restart guard (tap burst).** A re-triggerable one-shot has a subtlety the toggle case doesn't: while the previous commit loop is still winding down, a new tap must not `Commit` a second loop on top of it (re-entry). Guard with a flag that is **reset when the loop actually stops** (in `finished`, when `repeat` first returns `false`), and skip re-triggering while a loop is already running — new particles just join the live list:

     ```csharp
     private bool _burstActive;
     private readonly Stopwatch _sw = new();

     void OnTap(...)
     {
         SpawnParticles(...);          // add to the live list regardless
         if (_burstActive) return;     // a burst loop is already running; let it keep ticking
         _burstActive = true;
         _sw.Restart();
         new Animation(OnFrame, 0, 1)
             .Commit(this, "Burst", rate: 60, length: 1000,
                     easing: Easing.Linear,
                     finished: (_, _) => _burstActive = false,  // reset when the loop truly ends
                     repeat: AnyAlive);                          // stops as soon as the list is empty
     }

     bool AnyAlive() => _particles.Count > 0;

     void OnFrame(double value)
     {
         float dt = (float)_sw.Elapsed.TotalSeconds;  // wall-clock delta, not the callback cadence
         _sw.Restart();
         if (dt > 0.25f) dt = 0.25f;                  // clamp hiccups (suspend, debugger) so speed doesn't jump
         StepParticles(dt);                           // integrate positions/ages by dt
         InvalidateSurface();
     }
     ```

     The three-step `dt` idiom (`read Elapsed` — `Restart()` — **clamp** large `dt`) is what keeps particle speed and decay time-accurate even when the commit loop pauses or skips ticks.

  - `Animation.Commit` is MAUI's animation API, not SkiaSharp's — it's the idiomatic way to drive a SkiaSharp canvas smoothly. If you *also* need the GPU (shaders, tens of thousands of elements, a measured CPU shortfall), use `SKGLView` + `HasRenderLoop` (Section 4) instead; that is the one case where animation alone is a reason to reach for the GL view.

  ### Fallback: `Dispatcher` timer (only when you don't need smoothness)

  For low-frequency or event-driven updates (and fine on Android/iOS, but **stutters on Windows** — see Pitfalls). It's not the default for continuous animation: use `Animation.Commit` above.

  ```csharp
  Dispatcher.StartTimer(TimeSpan.FromMilliseconds(16), () =>
  {
      // advance state, InvalidateSurface()...
      return _running;   // keep ticking (toggle via _running), or return false to stop
  });
  ```

  For a re-triggerable one-shot (e.g. a tap burst), guard with a `_timerActive` flag that is **reset the moment the callback returns `false`** — otherwise it latches and a later tap can't restart it.
- **Input:** for interactive graphics (tap a chart point, drag, zoom), handle the gesture (see [gesture handling](#3-gesture-handling)), convert the pointer position into the coordinate system you chose (e.g. the `ToWorld` inverse above), update state, and invalidate. Keep hit-testing code separate from drawing code.

## 7. SkiaSharp 4.x API rules

SkiaSharp 4.x is a breaking release: the remaining pre-v4 obsolete APIs are compile errors. Do not copy SkiaSharp 3.x examples blindly; when an older example conflicts with the compiler, trust the compiler.

- **Paths: use `SKPathBuilder`, not mutable `SKPath`.**

  ```csharp
  using var builder = new SKPathBuilder();
  builder.MoveTo(0, 10);
  builder.LineTo(100, 10);
  using var path = builder.Detach();
  canvas.DrawPath(path, paint);
  ```

  Do not call the old mutating `SKPath.MoveTo`/`LineTo`/`AddRect`/`AddCircle`/`Close` APIs (obsolete) or suppress their warnings.

  The circle helper on the builder is `AddCircle(x, y, radius, SKPathDirection dir)` — the direction enum is **`SKPathDirection`**, not `SKSweepDirection`:

  ```csharp
  using var builder = new SKPathBuilder();
  builder.AddCircle(50, 50, 44, SKPathDirection.Clockwise);
  builder.Close();
  using var ring = builder.Detach();
  ```

- **There is no `SKCanvas.DrawLines` in 4.x.** The 3.x polyline `DrawLines(SKPoint[], paint)` was removed — a polyline is a compile error if copied from an old example. For a connected polyline (waveforms, sparklines, chart series), either:
  - build an `SKPathBuilder` once per frame (`MoveTo` first point, `LineTo` the rest, `Detach`) and `canvas.DrawPath(path, paint)`, or
  - loop `canvas.DrawLine(_points[i], _points[i + 1], paint)` over consecutive pairs.

  `SKCanvas` in 4.x has `DrawLine` (single segment), `DrawPoints` (a point set — `SKPointMode.Points` / `Line` / `Polygon`), `DrawCircle`, `DrawOval`, `DrawRect`, `DrawPath`, `DrawImage`, `DrawText`, etc. — but **no `DrawLines`**. `DrawPoints` with `SKPointMode.Line` also works for a polyline but cannot control per-segment paint state, so `DrawPath`/`DrawLine`-loop is the usual choice.

- **Text: use `SKFont` with `DrawText`, not the `SKPaint` font properties** (`paint.TextSize`/`paint.Typeface` still compile but are not the 4.x path — they are ignored once you pass a `SKFont` to `DrawText`, so don't rely on them).

  ```csharp
  var font = new SKFont(SKTypeface.Default, 14); // or a specific SKTypeface
  var width = font.MeasureText(text, paint);
  canvas.DrawText(text, x, y, SKTextAlign.Left, font, paint);
  ```

  A parameterless `new SKFont()` has an **empty typeface** — measurement and rendering won't work until a typeface is assigned; always pass one. Measure text instead of assuming widths (localized text widths vary).

- **Images:** decode once, cache the `SKImage`, and draw with the `SKSamplingOptions`-based overloads.

- **`SKCanvasView`** raises `PaintSurface` with `SKPaintSurfaceEventArgs` (`e.Info`, `e.Surface.Canvas`); invalidate with `InvalidateSurface()`.
- **`SKGLView`** raises `PaintSurface` with `SKPaintGLSurfaceEventArgs` (`e.RawInfo`, `e.Surface` — **no `GRContext`** in 4.x); draw on `e.Surface.Canvas` and (for continuous rendering) set `HasRenderLoop = true`. See [SKGLView — GPU rendering](#4-skiasharp--gpu-rendering).

- **Color & alpha: bake alpha into the color.** There is **no `SKPaint.Alpha`/`Alphaf`** property in 4.x — to fade, put the alpha in the color you set. Two paths:

  - **Simplest (byte `SKColor`)** — the byte `SKColor` constructor takes a **`byte` alpha** (0–255), and `SKPaint.Color` accepts it directly with no color space:

    ```csharp
    // Per-frame fade with the byte SKColor constructor (alpha 0..255):
    paint.Color = new SKColor(90, 255, 140, (byte)(255 * alpha01));
    ```

    This is the path for most fades, trails, and fading particles — no `SKColorSpace` argument, no extra type. (The 3-arg `new SKColor(r, g, b)` for opaque/static colors is fine too, as used throughout the §2/§4 examples.)

    **Fading a color you already hold:** there is no `SKColor(SKColor, byte alpha)` constructor and `SKColor` exposes no `R`/`G`/`B`/`A` accessors, so you cannot read the channels of a stored `SKColor` and dim it. For per-element fades (particles, trails, points) **store the raw `byte` channels in your model** and rebuild the 4-arg color each frame:

    ```csharp
    // Model holds byte R, G, B; alpha is recomputed per frame:
    paint.Color = new SKColor(p.R, p.G, p.B, (byte)(255 * alpha01));
    ```

  - **`SKColorF` + `SKPaint.SetColor`** — use when you need float-precision alpha or a specific color space. Two gotchas that bite on first use:
    - `SKColorF` has **only `(float, float, float[, float])` constructors** — `new SKColorF(90, 255, 140, a)` with `byte`/`int` components is a **compile error (CS1503)**. Use float literals: `new SKColorF(90f, 255f, 140f, a)`.
    - `SKColorF` has **no `.A` property** — to change alpha on an existing value use the `WithAlpha(float)` method (0–1), not `color.A = x`.
    - `SetColor(SKColorF, SKColorSpace)` **requires the `SKColorSpace` argument** (omitting it is a compile error):

      ```csharp
      // Fade with SKColorF; always pass a color space.
      paint.SetColor(baseColor.WithAlpha(alpha01), SKColorSpace.CreateSrgb());
      ```

  **There is also no `SKPaint.ColorType` property in 4.x** — the 3.x idiom `new SKPaint { ColorType = SKColorType.Rgba }` is a compile error (CS0117).

  The byte `SKPaint.Color` (`SKColor`) and `paint.TextSize`/`paint.Typeface` still exist as properties; for per-frame alpha the byte `SKColor` constructor is the current 4.x default, with `SKColorF` + `SetColor` for float precision or a specific color space.

## 8. Resources, performance & pitfalls

**Resource lifetime**

- `SKPaint`, `SKFont`, and `SKTypeface` are cheap value-like objects: reuse them as static/instance fields instead of allocating per frame.
- `SKPath`, `SKImage`, `SKShader`, and decoded bitmaps are native resources: `using` / dispose them properly, and cache decoded images and expensive geometry instead of rebuilding them every frame.
- **Fonts:** load a bundled font into an `SKTypeface` **once**, cache it, and build a `SKFont` from it per paint. `SKTypeface.FromStream` copies the font data into the typeface, so the source stream can be disposed immediately:

  ```csharp
  using var s = await FileSystem.OpenAppPackageFileAsync("Foo.ttf");
  var typeface = SKTypeface.FromStream(s, 0); // (stream, faceIndex) — there is no 1-arg overload; s can be disposed now
  // later, per paint:
  var font = new SKFont(typeface, 14);
  ```

  `SKTypeface.FromFamilyName("Arial", ...)` relies on platform font resolution and can silently fall back — use an explicit bundled typeface for consistent cross-platform rendering. Bundle the `.ttf` via `<MauiFont Include="Resources\Fonts\*" />` and open it with `FileSystem.OpenAppPackageFileAsync`.

  **Loading is asynchronous, so guard the first paint.** Fonts are loaded on startup but a canvas may paint before loading finishes. Cache the typeface in a static holder that defaults to `SKTypeface.Default`, load once, and expose **both a ready *signal* and a loaded *state*** so the control can pick up the real typeface and invalidate:

  ```csharp
  public static class AppFonts
  {
      public static SKTypeface Display { get; private set; } = SKTypeface.Default;
      public static bool IsLoaded { get; private set; }
      public static event Action? Ready;

      public static async Task LoadAsync()
      {
          using var s = await FileSystem.OpenAppPackageFileAsync("Display.ttf");
          Display = SKTypeface.FromStream(s, 0); // (stream, faceIndex) — no 1-arg overload
          IsLoaded = true;
          Ready?.Invoke();
      }
  }
  ```

  In the control: build the cached `SKFont` **once** with `SKTypeface.Default` as a placeholder (a parameterless `new SKFont()` has an empty typeface and won't render), draw with it in the paint callback (nothing crashes — it just falls back to the default face until the real one arrives), and **in the constructor handle both load timings**:

  ```csharp
  // Field:
  private readonly SKFont _font = new SKFont(SKTypeface.Default, 26); // placeholder

  // Constructor — check loaded state first, else subscribe:
  if (AppFonts.IsLoaded)
      OnFontReady();                 // already loaded: swap in now
  else
      AppFonts.Ready += OnFontReady; // still loading: swap in when it fires

  // Paint callback: use _font directly (Default until loaded).
  // Ready handler (UI thread):
  void OnFontReady()
  {
      AppFonts.Ready -= OnFontReady; // no-op if we never subscribed; otherwise unsubscribe
      _font.Typeface = AppFonts.Display;   // SKFont.Typeface is settable
      InvalidateSurface();
  }
  ```

  The swap works because **`SKFont.Typeface` is settable** — on load you do **not** rebuild the `SKFont`, you reassign its typeface and invalidate. This is the load-bearing line of the whole pattern; the cached `SKFont` object stays the same, only its `Typeface` changes.

  Trigger `LoadAsync()` **fire-and-forget from the `App` constructor** (or `AppShell`/the hosting page's `Appearing`) — `MauiProgram.CreateMauiApp` returns synchronously, so there is no clean post-`Build()` hook there to await from. `AppFonts.Ready` fires on the UI thread (the await resumes there), so the control's ready handler can swap the typeface and invalidate directly.

  > **The one-shot `Ready` event is not sufficient on its own.** `LoadAsync()` runs before the page (and any control) is constructed, so it can **complete before a control subscribes** — the event then fires with no listeners and is lost, and the control silently stays on `SKTypeface.Default`. The `IsLoaded` flag closes this: a late-arriving control reads the already-loaded typeface directly instead of waiting for a signal that already went out. Always check state *and* subscribe.

- Do not read `Application.Current.Resources` in static field initializers (the type may load before `Application.Current` exists, and static colors never react to theme changes) — resolve colors lazily or per paint.
- **Random:** `SKRandom` does not exist in SkiaSharp 4.x. Use `System.Random` for particle effects, random speeds, etc. Note `System.Random` has **no `NextSingle()` and no `Next(float, float)`/`Next(int, int)` float range** in .NET — derive a float range from `NextDouble()`:

  ```csharp
  float v = min + (max - min) * (float)random.NextDouble(); // uniform in [min, max)
  ```

**Performance checklist (in this order)**

1. Measure before optimizing; do not switch to `SKGLView` as a first optimization step.
2. Check per-frame allocations and resource recreation.
3. Check whether geometry is recalculated when only a visual property changed.
4. Check invalidation frequency (unnecessary `InvalidateSurface()` calls).
5. Only then consider `SKGLView` / shaders / a different rendering architecture.

**Pitfalls**

- **Don't use SkiaSharp for normal UI.** And don't reach for `SKGLView` just to animate — drive a smooth CPU `SKCanvasView` with **`Animation.Commit`** (Section 6). Reserve `SKGLView` for real GPU needs (shaders, scale, measured CPU shortfall).
- **Don't drive continuous animation with the plain `Dispatcher` timer on Windows** — it quantizes to ~20–40ms and stutters. Use `Animation.Commit` (Section 6) for smooth motion on all platforms.
- **Don't confuse MAUI DIPs with Skia pixels**, and don't apply the density scale more than once per paint.
- **Don't assume the canvas size is fixed** — orientation, window resizing, split screen, and device changes all change `e.Info`.
- **Don't let stale transforms leak:** wrap temporary `Translate`/`Scale`/`Rotate`/clip in `Save()`/`Restore()`.
- **Don't put business logic or `Debug.WriteLine` in the paint callback** — it runs on every redraw.
- **Don't rely on `SKCanvasView.Touch`** — it is not reliably raised in the MAUI variant. Use `TapGestureRecognizer` or `PointerGestureRecognizer` (see [gesture handling](#3-gesture-handling)).
- **Don't forget `using SkiaSharp.Views.Maui;`** — `SKPaintSurfaceEventArgs` and `SKTouchEventArgs` live there, not in `SkiaSharp` or `SkiaSharp.Views.Maui.Controls`.
- **Don't set `HeightRequest` on `SKCanvasView` subclasses in XAML** — the MAUI handler does not expose it as a `BindableProperty`. Wrap in a `Border` or `Frame` instead.
- **Don't use the GL render loop as the animation clock.** When `HasRenderLoop = true`, advance state from wall-clock time (`DateTime.UtcNow` deltas), not from frame counts — the loop's cadence varies by device.
- **Blurry thin line?** Check coordinate system, scale, stroke width, anti-aliasing, and whether the geometry lands between physical pixels — before increasing the stroke width.

## 9. Workflow

1. Pick the surface: `SKCanvasView` by default; `SKGLView` only for a concrete GPU/continuous-rendering requirement (see [Quick decision guide](#quick-decision-guide)).
2. Build the control: subclass `SKCanvasView` (preferred when the control is the canvas) or wrap in a `ContentView` (when the canvas is one of several child views). Expose a small `BindableProperty` API; invalidate on data change.
3. Draw in one consistent coordinate system (fixed world + fit, or DIP with a single scale), using `e.Info` for size; keep drawing in static renderer helpers.
4. Use SkiaSharp 4.x APIs: `SKPathBuilder`, `SKFont`, `SKSamplingOptions` (Section 7).
5. Handle input with `TapGestureRecognizer` / `PointerGestureRecognizer` (Section 3); convert pointer coordinates with the inverse of your drawing transform.
6. If using `SKGLView`, enable the render loop and draw on `e.Surface.Canvas` (Section 4) — there is no `e.GRContext` to create a surface from in 4.x.
7. Verify: build, resize the window/orientation, switch light/dark theme, check different densities, and (if interactive) confirm input maps to the right world coordinate before considering performance work.

## References

- .NET MAUI + SkiaSharp (Microsoft Learn): https://learn.microsoft.com/en-us/dotnet/maui/hybridize/skiasharp
- Custom control with SkiaSharp (step-by-step how-to): https://blog.ewers-peters.de/how-to-write-a-custom-control-for-net-maui-using-skiasharp
- MAUI `Animation` API (`Animation.Commit`, used in Section 6): https://learn.microsoft.com/en-us/dotnet/api/microsoft.maui.controls.animation
- SkiaSharp 4.0 release announcement: https://devblogs.microsoft.com/dotnet/skiasharp-4-0-stable/
- SkiaSharp release notes: https://github.com/mono/SkiaSharp/releases
- Sibling skill: `net-maui-custom-control` (semantic control architecture)
