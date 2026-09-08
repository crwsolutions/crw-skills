Main objective: complete the validation task for the skill text.

## Constraints

- **Self-contained:** rely only on the skill text and this task. Do not consult external sources — no web/browser lookups, no package (NuGet) documentation, no help/documentation sites (MS Learn, StackOverflow, GitHub), and no other local projects or codebases.
- Add only the package references and project settings specified in this task or the skill; do not research or add others.
- The bundled font for the font showcase ships alongside this task in `showcases\net-maui-skiasharp\fonts\`. Copy it into the project as described in Prerequisites; do not look elsewhere for a font.

## Prerequisites

- Create a blank .NET MAUI project in `E:\temp` (run from `E:\temp`):

  ```powershell
  dotnet new maui -n SkiaSharpShowcase
  ```

- Add the package to the generated `.csproj`:

  ```xml
  <PackageReference Include="SkiaSharp.Views.Maui.Controls" Version="4.*" />
  ```

- In `MauiProgram.cs`, initialize SkiaSharp with `.UseSkiaSharp()` (see the skill's prerequisites).
- For the font showcase: copy `Marimpa.ttf` from
  `E:\repos\crwsolutions\crw-skills\showcases\net-maui-skiasharp\fonts\Marimpa.ttf`
  into the project's `Resources\Fonts\` folder (the template's `<MauiFont Include="Resources\Fonts\*" />` picks it up automatically).
- Compile the project before implementing to confirm it builds (compiling only the Windows TFM is fine for speed).

This assignment is only intended to validate the skill text. Create a showcase and provide clear feedback about the contents of the skill. This is about the .NET MAUI SkiaSharp skill.

## Task

Based on the skill, implement the five controls below in `MainPage.xaml` as a showcase, each in its own file under `Controls/`. Every control is small — roughly a 260×160 box — and every control must visibly **animate or react**. Keep each implementation compact (one drawing pass, one animation loop, one render loop, or one interaction).

## Showcase

| # | Control | Surface | Requirement |
|---|---|---|---|
| 1 | `PulsingHeart` | `SKCanvasView` subclass | A pulsing heart: build the heart shape with `SKPathBuilder`, fill it, and pulse it (scale 1.0 → 1.15 and back) using the skill's recommended animation driver, updating a progress field and invalidating the surface. A "Tap to stop/start" `TapGestureRecognizer` on the control toggles the animation. |
| 2 | `RadarSweep` | `SKCanvasView` subclass | A radar screen: 3 concentric rings + crosshair in a dark green tone, and a rotating sweep line with a fading trail (draw ~20 lines behind the current angle with decreasing alpha). Use the skill's fixed-world + fit coordinate system (e.g. 100×100 world), fit and centered. Drive the rotation with the skill's recommended animation driver. |
| 3 | `ParticleBurst` | `SKCanvasView` subclass | A burst-on-tap canvas: tap anywhere and spawn ~40 small colored circles at the tap point that fly outward with random speed and fade out over ~1 second (a timer drives the particle update + invalidation while particles are alive). The tap point must be converted to the canvas coordinate system (inverse of the transform used for drawing). Use a `PointerGestureRecognizer` on the canvas. |
| 4 | `FontShowcase` | `SKCanvasView` subclass | A text control that renders the same string twice: once with a **bundled typeface** (the `Marimpa.ttf` copied in Prerequisites) and once with `SKTypeface.Default`. Load the font once with the skill's async font pattern (static holder defaulting to `SKTypeface.Default`, `SKTypeface.FromStream`, a ready signal) and pick up the real typeface when it loads. This demonstrates that the skill covers bundled-font loading. |
| 5 | `GLWaveform` | `SKGLView` subclass | A GPU-rendered animated sine wave: subclass `SKGLView`, enable the render loop (`HasRenderLoop = true`), and in the `PaintSurface` handler (`SKPaintGLSurfaceEventArgs`) create a surface from `e.GRContext` + `e.RawInfo` and draw a moving waveform (advance a phase from wall-clock time). This demonstrates the skill's `SKGLView` section. |

## Build instructions

- Each control is a subclass of `SKCanvasView` (controls 1–4) or `SKGLView` (control 5) — the skill's preferred pattern when the control **is** the canvas. Subscribing to `PaintSurface` happens in the constructor; `InvalidateSurface()` is called on `this`.
- `MainPage.xaml`: one `ScrollView` → `VerticalStackLayout` with a `Label` section header per control ("1. PulsingHeart" … "5. GLWaveform") and a one-line caption per control. Because the MAUI handler does not expose `HeightRequest` on the canvas subclass, wrap each control in a `<Border HeightRequest="160" Padding="0" BackgroundColor="Transparent">`.
- All drawing in one consistent coordinate system per control (fixed-world + fit); guard against zero-size surfaces; reuse `SKPaint`/`SKFont` instances instead of allocating per frame.
- All visuals dark-themed (the controls draw their own background).
- Include the required `using` statements (`SkiaSharp`, `SkiaSharp.Views.Maui`, `SkiaSharp.Views.Maui.Controls`).
- Compile the project at the end (Windows TFM is enough).

## Feedback

After implementing, report back on the skill text itself:

- Which parts were ambiguous, missing, or wrong (cite the section).
- Anything you had to work out that the skill should spell out (e.g. exact type/namespace/enum names, XAML sizing, async font timing, GLView surface creation).
- Whether each showcase control (1–5) could be built from the skill text alone, and where it could not.
