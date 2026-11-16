---
name: csharp-generated-regex
description: Use this skill when writing or refactoring C# regular expressions, especially when the pattern is a compile-time constant and can use the .NET GeneratedRegex source generator.
---

# C# Generated Regular Expressions

Prefer the built-in .NET `GeneratedRegex` source generator whenever a regular-expression pattern is known at compile time. It generates the regex implementation at build time, enabling compile-time validation and optimized matching.

## Rules

- For constant patterns, prefer `[GeneratedRegex]` over string-pattern overloads and avoid constructing `new Regex(...)` at repeated use sites.
- Declare the generated regex as a `static partial` method returning `Regex`. The method must have no parameters.
- Mark the containing class `partial`. If the method is in a nested type, every containing type must also be `partial`.
- Specify `RegexOptions.CultureInvariant` unless culture-sensitive matching is intentional. This is especially important when using `IgnoreCase`.
- Do not specify `RegexOptions.Compiled`; it is not needed for a source-generated regex.
- When matching untrusted input, set a finite match timeout with the `matchTimeoutMilliseconds` argument.
- Keep using the normal `Regex` APIs for patterns that are genuinely dynamic at runtime.
- Check compiler diagnostics: unsupported constructs can prevent the generator from producing a specialized implementation.

## Example

```csharp
using System.Text.RegularExpressions;

public static partial class ProductCodeValidator
{
    [GeneratedRegex(
        @"\A[A-Z]{3}-\d{4}\z",
        RegexOptions.CultureInvariant,
        matchTimeoutMilliseconds: 500)]
    public static partial Regex ProductCodeRegex();

    public static bool IsValid(string input) => ProductCodeRegex().IsMatch(input);
}
```

Use the returned `Regex` with the regular APIs:

```csharp
ProductCodeValidator.IsValid(input);
ProductCodeRegex().Match(input);
ProductCodeRegex().Matches(input);
ProductCodeRegex().Replace(input, "");
ProductCodeRegex().Split(input);
```

Expose the generated method only when callers need direct access to the `Regex`; otherwise keep it private and expose a small operation such as `IsValid`. Use `MatchEvaluator` when a replacement needs custom C# logic.

## Requirements

- `GeneratedRegexAttribute` is available starting with .NET 7.
- The source generator requires a `static partial` method returning `Regex`; it does not target properties.
- The class containing the method must be `partial`. All containing types must be `partial` for a nested method.
- The project must target a framework that provides `GeneratedRegexAttribute` and compile with a compatible C# language version (C# 11 or later).
- The generator may be unable to specialize some constructs. Review build diagnostics and verify behavior rather than assuming every attribute produces generated code.

Apply this preference in new code and when refactoring existing constant-pattern regexes, while preserving the original matching semantics.
