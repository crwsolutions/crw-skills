Main objective: complete the validation task for the skill text.

## Constraints

- **Self-contained:** rely only on the skill text and this task. Do not consult external sources — no web/browser lookups, no package (NuGet) documentation, no help/documentation sites (MS Learn, StackOverflow, GitHub), and no other local projects or codebases.
- Add only the package references and project settings specified in this task or the skill; do not research or add others.

## Prerequisites

- Create a blank .NET MAUI project in `E:\temp` (run from `E:\temp`):

  ```powershell
  dotnet new maui -n PopupShowcase
  ```

- Add the packages to the generated `.csproj`:

  ```xml
  <PackageReference Include="CommunityToolkit.Maui" Version="*" />
  <PackageReference Include="CommunityToolkit.Mvvm" Version="*" />
  ```

- In `MauiProgram.cs`, register the toolkit with `.UseMauiCommunityToolkit()`.
- Compile the project before implementing to confirm it builds (compiling only the Windows TFM is fine for speed).

This assignment is only intended to validate the skill text. Create a showcase and provide clear feedback about the contents of the skill. This is about the .NET MAUI popup skill.

Based on the skill, create these buttons (from top to bottom) in `MainPage.xaml` as a showcase, with a section label for each grouping. Each button demonstrates exactly one pattern from the skill:

## Popup — Simple
| Button | Shows |
|---|---|
| **Alert (OK)** | information message |
| **Confirm (Yes/No)** | "Yes"/"No", returns the bool in a log |
| **Action Sheet** | choice list, shows the selected option |
| **Prompt** | text input, shows the entered text |

## Popup — Simple inline
| Button | Shows |
|---|---|
| **Inline popup** | Popup built entirely in C# + `PopupOptions` (overlay + `RoundRectangle`), closed via `Shell.Current.ClosePopupAsync()` |

## Popup — Complex / DI + Shell
| Button | Shows |
|---|---|
| **DI popup** | popup registered with `AddTransientPopup`, opened via `IPopupService.ShowPopupAsync<VM>(Shell.Current, options)` |

## Popup — Complex with input
| Button | Shows |
|---|---|
| **Input via query attributes** | `shellParameters` dictionary and `IQueryAttributable` in the popup VM |
| **Input via BindingContext** | `PopupOptions.BindingContext` = caller VM (optional, as a demonstration of 4.2) |

## Popup — Complex with output
| Button | Shows |
|---|---|
| **Result popup (bool)** | `Popup<bool>` or `ShowPopupAsync<T, bool>`, check `WasDismissedByTappingOutsideOfPopup`, log the result |
| **Result popup (string)** | Optional: `Popup<string>` with an `Entry` and return button (similar to the toolkit's `ComplexPopup`) to show `Popup<T>` with input + result |

## Snackbar / Toast
| Button | Shows |
|---|---|
| **Snackbar plain** | standard `Snackbar.Make(text)` |
| **Snackbar + action** | `Snackbar.Make` with an action button ("Undo") |
| **Snackbar styled** | `SnackbarOptions` with custom colors / corner radius |
| **Toast** | Optional: `Toast.Make` for comparison (less setup required) |

## Customizing
| Button | Shows |
|---|---|
| **Bottom-anchored popup** | `VerticalOptions="End"` + `HorizontalOptions="Fill"` (bottom-sheet style), showing positioning |
| **No outside-tap dismiss** | `CanBeDismissedByTappingOutsideOfPopup = false`, forcing explicit close |

**Total: ~14–16 buttons** (with the optional items). Without the optional items (BindingContext input, string result, Toast), you end up with **12 buttons** — this is the clean set that covers each chapter of the skill at least once.

Instructions for the build:
- One vertical `VerticalStackLayout` in `MainPage.xaml`, with `Label` section headers above each block (Simple / Inline / Complex / Input / Output / Snackbar / Customizing).
- Show results (`bool` / `string` / `string?`) in a `Toast` or create a result label at the bottom of the page outside a `ScrollView`, so it is always visible while you can still scroll through the buttons.
- Each button has a handler that directly calls the matching pattern (for showcase purposes, this may be in the code-behind; the DI patterns show how to do it via the VM).