# Refactor an Inline Regex to GeneratedRegex

## Goal

Validate the `csharp-generated-regex` skill by replacing an inline constant regex with a source-generated regex while preserving its behavior.

## Constraints

- Implement the task using only the skill and this showcase; do not install packages.
- Use an existing C# project or create a small console project targeting .NET 7 or later.
- Keep the example focused: no UI, external dependencies, or unrelated refactoring.

## Starting point

Add a product-code validator using this initial implementation:

```csharp
using System.Text.RegularExpressions;

public static class ProductCodeValidator
{
    public static bool IsValid(string input) =>
        Regex.IsMatch(input, @"\A[A-Z]{3}-\d{4}\z");
}
```

The pattern accepts exactly three uppercase ASCII letters, a hyphen, and four digits, with no extra characters.

## Task

1. Refactor the constant pattern to use `[GeneratedRegex]`.
2. Keep the pattern and options in one private `static partial Regex` method, and make the containing class `partial`.
3. Use `RegexOptions.CultureInvariant` and a finite timeout because the validator processes input supplied by callers.
4. Keep `IsValid` as the public API and have it use the generated regex.
5. Add a small executable check or unit tests for the cases below. Do not change the pattern to make any invalid case pass.

| Input | Expected |
|---|---|
| `ABC-1234` | valid |
| `XYZ-0000` | valid |
| `AB-1234` | invalid |
| `abcd-1234` | invalid |
| `ABC-123` | invalid |
| `ABC-12345` | invalid |
| `ABC-1234` followed by a newline | invalid |

## Verify

- Build the project and run the checks.
- Confirm the implementation uses the source-generated method, not `Regex.IsMatch(input, pattern)` or `new Regex(...)`.
- Report the target framework, build/test result, and any source-generator diagnostic or behavior discrepancy.
