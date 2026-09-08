Main objective: complete the validation task for the skill text.

## Constraints

- **Self-contained:** rely only on the skill text and this task. Do not consult external sources — no web/browser lookups, no package (NuGet) documentation, no help/documentation sites (MS Learn, StackOverflow, GitHub), and no other local projects or codebases.
- Add only the package references and project settings specified in this task or the skill; do not research or add others.

## Prerequisites

- Create a blank .NET MAUI project in `E:\temp` (run from `E:\temp`):

  ```powershell
  dotnet new maui -n CustomControlShowcase
  ```

- In the generated `.csproj`, add `<MauiXamlInflator>SourceGen</MauiXamlInflator>` to a `PropertyGroup`.
- Compile the project before implementing to confirm it builds (compiling only the Windows TFM is fine for speed).

This assignment is only intended to validate the skill text. Create a showcase and provide clear feedback about the contents of the skill. This is about the .NET MAUI custom-control skill.

## Task

Based on the skill, implement each of the following controls in its own file under `Controls/` and place them all in `MainPage.xaml` as a showcase, with a section label for each grouping. The requirement is stated — use the skill's decision guide to pick the base class and the skill's XAML-control conventions for the implementation. Keep every visual small: one compact row per control.

## Button-derived

| Control | Requirement |
|---|---|
| `NavigationButton` | Button with a large chevron after the text; `Direction` (enum: Forward/Backward) flips the chevron; must keep `Command`/`CommandParameter` (wire a command in the page that logs to the result label) |
| `GlyphIconButton` | Square 44×44 button that renders a single Unicode glyph (e.g. "✕"); `Glyph` + `GlyphColor`; has a `Command` |

## Entry-derived

| Control | Requirement |
|---|---|
| `ValidatedEntry` | Text input that shows a red border + an error message below when invalid; `IsValid` (bool) and `Error` (string); a "Validate" button in the page sets `IsValid=false` and `Error="Required"` |

## Form composites (layout-based)

| Control | Requirement |
|---|---|
| `FormEntry` | Label + required-star + entry + error row; `LabelText`, `EntryPlaceholder`, `IsRequired`, `Value` (string, two-way), `Error` |
| `FormSwitch` | Label + required-star + switch; `LabelText`, `IsRequired`, `Value` (bool?, two-way); log changes to the result label |

## Shape-based

| Control | Requirement |
|---|---|
| `InfoPanel` | Icon + text panel whose color depends on `InfoPanelType` (enum: Info/Warning/Error); `Text` |
| `CircleAvatar` | Circle that centers its content; `Diameter` (double); shows a Unicode glyph (e.g. "☺") |
| `ChipToggle` | Pill-shaped toggle; `Text`, `IsSelected` (bool, two-way); log toggles to the result label |

## Dynamic layout

| Control | Requirement |
|---|---|
| `Timeline` | Vertical timeline: a line + a dot per item, title + subtitle; `ItemsSource` over a small `record TimelineItem(string Title, string When)` with 3 sample items; the internal visual tree is built from the data in code |

## Interactive composite

| Control | Requirement |
|---|---|
| `StarRating` | Five star glyphs (Unicode "★"); tapping a star sets `Value` (int 0–5, two-way); log to the result label |

## ContentView

| Control | Requirement |
|---|---|
| `UserCard` | Card with an avatar circle (glyph), a bold name, and a role; `Name`, `Role`, `AvatarGlyph` |
| `SectionCard` | Header (glyph + title + a small "edit" button with a `Command` that logs) and a content area via `ContentPresenter` + `[ContentProperty]`; usage with inline content (e.g. a short `Label`) |

## No custom control needed

| Item | Requirement |
|---|---|
| Styled `Button` | A "Save" button whose look (colors, corner radius) comes from a `Style` in `App.xaml` — not a custom control |
| Styled `Entry` | An `Entry` styled via a `Style` in `App.xaml` (e.g. outline look) — not a custom control |

**Total: 12 custom controls + 2 existing-control rows.**

## Build instructions

- All custom controls live in `Controls/`, one file per control, following the skill's XAML conventions (`x:Name="This"`, `x:DataType`, self-reference binding, theme-aware colors).
- `MainPage.xaml`: one `ScrollView` with a `VerticalStackLayout`; a `Label` section header above each group (the section names above); each control on its own row with a small caption (the control name).
- A result `Label` at the bottom of the page, outside the `ScrollView`, always visible, showing the last interaction (e.g. `NavigationButton: Forward`, `StarRating = 4`, `ChipToggle selected`).
- Unicode glyphs only — no icon-font packages.
- Compile the project at the end.

## Implementation tips

These tips are about the **showcase task itself**, not the skill. The skill text is being validated *through* this task — do not add implementation tips that cover things the skill should cover, because that would bypass the validation. Only keep tips that are specific to how to run/verify this particular showcase.

1. **Compile after every 2–3 controls, not only at the end.** Most failures are compile-time (missing symbols) or XAML-inflation errors; catching them early avoids a giant final failure. Use the Windows TFM for speed.
2. **Report, don't fight, when the skill's own guidance causes a failure.** This is a validation task: if following the skill's stated pattern leads to a build error, runtime crash, or hang, implement the working version *and* record the discrepancy as feedback about the skill. Do not burn time trying to make an impossible pattern succeed — record it as a skill gap instead.
