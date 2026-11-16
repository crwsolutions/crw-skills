---
name: dotnet-normalize-lineendings
description: Use this skill when normalizing or auditing line endings in a .NET (or any) Git repository. It covers diagnosing mixed CRLF/LF files, creating a correct .gitattributes, ensuring .editorconfig enforces LF, normalizing tracked files in place with PowerShell, verifying with git and byte-level scans, and understanding how core.autocrlf and core.eol interact with .gitattributes.
---

# .NET Normalize Line Endings

Standard procedure for auditing and normalizing line endings in a Git repository, with a focus on .NET projects on Windows where `core.autocrlf=false` (or absent) causes CRLF files to accumulate over time.

This skill contains the full instructions. Follow them in order: diagnose → create `.gitattributes` → ensure `.editorconfig` → normalize → verify → commit.

## When to use

- A .NET (or any) repository has mixed or inconsistent line endings.
- The user wants to standardize line endings to LF (or CRLF) across a Git repository.
- `git diff` shows spurious whole-file changes after a line-ending conversion.
- A repository lacks a `.gitattributes` file and is showing CRLF/LF drift between Windows and non-Windows contributors.
- The user asks about `core.autocrlf`, `core.eol`, or why Git is not normalizing line endings.

> **Out of scope:** changing line endings of binary files (images, fonts, `.pdb`, etc.) — these should be left alone and marked `binary` in `.gitattributes`.

## Which files to normalize

Use an **allowlist** of text extensions that should be converted to LF. This is safer than an exclusion list because it never accidentally touches binary files, generated assets, or files whose extension is not in the known-text set.

The default allowlist:

```
cs  csx  csproj  slnx  sln  props  targets  xaml  json  http
ts  js  css  html  xml  md  yml  yaml  sh  editorconfig
```

Plus the special dot-files `.gitignore` and `.gitattributes` (no extension).

Files **not** in the allowlist are left completely untouched. If the repository uses additional text extensions (e.g. `.razor`, `.fsx`, `.tf`, `.tfvars`), add them to the list before running the conversion.

Check which extensions are present in the repo to decide if the list needs extending:

```powershell
git ls-files | ForEach-Object { [System.IO.Path]::GetExtension($_).TrimStart('.') } | Sort-Object -Unique
```

## Diagnosis

Run this PowerShell script from the repository root to get a full picture before changing anything. It reports per-extension counts and identifies mixed files.

```powershell
# Line-ending audit — run from the repo root
# Uses the same allowlist as the normalization step
$allowed = @('cs','csx','csproj','slnx','sln','props','targets','xaml','json','http','ts','js','css','html','xml','md','yml','yaml','sh','editorconfig')

$files = git ls-files
$extStats = @{}
$mixed = @()
$skipped = 0

foreach ($f in $files) {
    $ext = [System.IO.Path]::GetExtension($f).TrimStart('.')
    $isDotFile = ($f -match '(?i)^(\.gitignore|\.gitattributes|\.editorconfig)$')

    if (-not $isDotFile -and $allowed -notcontains $ext) { $skipped++; continue }

    $bytes = [System.IO.File]::ReadAllBytes($f)
    $crlf = 0; $lf = 0
    for ($i = 0; $i -lt $bytes.Length; $i++) {
        if ($bytes[$i] -eq 10) {
            if ($i -gt 0 -and $bytes[$i-1] -eq 13) { $crlf++ } else { $lf++ }
        }
    }

    $key = if ($isDotFile) { $f } else { $ext }
    if ($crlf -gt 0 -and $lf -gt 0) { $mixed += "$f (CRLF=$crlf, LF=$lf)" }

    if (-not $extStats.ContainsKey($key)) { $extStats[$key] = @{ CRLF = 0; LF = 0; Mixed = 0 } }
    if ($crlf -gt 0 -and $lf -gt 0) { $extStats[$key].Mixed++ }
    elseif ($crlf -gt 0) { $extStats[$key].CRLF++ }
    else { $extStats[$key].LF++ }
}

Write-Host "=== Per-extension breakdown (allowed extensions only) ==="
$extStats.GetEnumerator() | Sort-Object Name | ForEach-Object {
    Write-Host ("{0,-15} CRLF={1,4}  LF={2,4}  Mixed={3,3}" -f $_.Name, $_.Value.CRLF, $_.Value.LF, $_.Value.Mixed)
}
Write-Host "`nSkipped (not in allowlist): $skipped files"

if ($mixed.Count -gt 0) {
    Write-Host "`n=== Mixed files (CRLF AND LF in same file) ==="
    $mixed | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "`nNo mixed files."
}
```

Also check the current Git configuration and existing config files:

```powershell
Write-Host "core.autocrlf = $(git config core.autocrlf)"
Write-Host "core.eol      = $(git config core.eol)"

$hasGitAttrs = Test-Path .gitattributes
$hasEditorCfg = Test-Path .editorconfig
Write-Host ".gitattributes present: $hasGitAttrs"
Write-Host ".editorconfig  present: $hasEditorCfg"
```

**Key finding to report to the user:** if `core.autocrlf=false` and there is no `.gitattributes`, Git performs no EOL conversion at all — files are checked in and out exactly as they are on disk. On Windows this means editors (VS, Notepad) write CRLF and that CRLF ends up in the repository permanently.

## Step 1 — Create or update `.gitattributes`

Create `.gitattributes` at the repository root if it does not exist. If it already exists, add the missing rules without removing existing ones.

Use the same allowlist as the normalization step. Mark only known binary types explicitly; the `* text=auto` line handles everything else.

```gitattributes
# Set default behaviour: normalize line endings to LF on check-in,
# let git decide on checkout (respects core.autocrlf).
* text=auto

# Explicitly mark known binary files
*.png    binary
*.jpg    binary
*.jpeg   binary
*.gif    binary
*.ico    binary
*.woff   binary
*.woff2  binary
*.ttf    binary
*.eot    binary

# Text files — enforce LF
*.cs             text eol=lf
*.csx            text eol=lf
*.csproj         text eol=lf
*.slnx           text eol=lf
*.sln            text eol=lf
*.props          text eol=lf
*.targets        text eol=lf
*.xaml           text eol=lf
*.json           text eol=lf
*.http           text eol=lf
*.ts             text eol=lf
*.js             text eol=lf
*.css            text eol=lf
*.html           text eol=lf
*.xml            text eol=lf
*.md             text eol=lf
*.yml            text eol=lf
*.yaml           text eol=lf
*.sh             text eol=lf
*.editorconfig   text eol=lf
.gitignore       text eol=lf
.gitattributes   text eol=lf

# Windows batch files must stay CRLF
*.cmd            text eol=crlf
*.bat            text eol=crlf
```

> Add more text extensions here if the repository uses them (e.g. `.razor`, `.fsx`). Keep the allowlist in sync between `.gitattributes` and the PowerShell scripts below.

## Step 2 — Ensure `.editorconfig` enforces LF

Editors (VS, VS Code, Rider) read `.editorconfig` to determine how to save files. Without `end_of_line = lf` set, a Windows editor will silently write CRLF on save, reintroducing the problem even after normalization.

### If `.editorconfig` does not exist

Create it at the repository root:

```editorconfig
# editorconfig.org
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
```

### If `.editorconfig` already exists

Check the `[*]` section for `end_of_line`. If it is set to `crlf` or `cr`, change it to `lf`. If the `[*]` section has no `end_of_line` key at all, add it. If the value is already `lf`, no change is needed.

```editorconfig
# In the [*] section of the existing .editorconfig:
[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
```

> **Do not** add `end_of_line` to a `[*]` section that already sets it to `lf` — that would be a no-op. Only make the change when the value is absent or set to something other than `lf`.

> **Exception:** if the `.editorconfig` intentionally sets `end_of_line = crlf` for a specific sub-section (e.g. `[*.{cmd,bat}]`), leave that sub-section alone. Only ensure the top-level `[*]` defaults to `lf`.

## Step 3 — Normalize working-tree files

`git add --renormalize .` updates the **index** (what will be committed) but does not rewrite the working-tree files when `core.eol` is not set. To also fix the working tree, convert files in place.

```powershell
# Convert allowed text files from CRLF (or mixed) to LF in the working tree.
# Only files in the allowlist are touched — everything else is left as-is.
$allowed = @('cs','csx','csproj','slnx','sln','props','targets','xaml','json','http','ts','js','css','html','xml','md','yml','yaml','sh','editorconfig')

$converted = 0
$untouched = 0

foreach ($f in (git ls-files)) {
    $ext = [System.IO.Path]::GetExtension($f).TrimStart('.')
    $isDotFile = ($f -match '(?i)^(\.gitignore|\.gitattributes|\.editorconfig)$')

    if (-not $isDotFile -and $allowed -notcontains $ext) { $untouched++; continue }

    $bytes = [System.IO.File]::ReadAllBytes($f)
    $hasCrlf = $false
    for ($i = 0; $i -lt $bytes.Length; $i++) {
        if ($bytes[$i] -eq 10 -and $i -gt 0 -and $bytes[$i-1] -eq 13) { $hasCrlf = $true; break }
    }

    if ($hasCrlf) {
        # Strip CR bytes at the byte level. Do NOT use
        # [System.IO.File]::WriteAllText($f, $text -replace "`r`n", "`n"):
        # on some PowerShell builds the -replace result does not bind to
        # the (string, char[], Encoding?) overload and every write fails
        # with "Cannot find an overload for WriteAllText and the argument
        # count: 3" while the counter keeps incrementing. Working on raw
        # bytes is immune to string overload resolution and also cannot
        # corrupt a BOM (it only removes 0x0D that immediately precedes 0x0A).
        $outBytes = New-Object byte[] $bytes.Length
        $w = 0
        for ($i = 0; $i -lt $bytes.Length; $i++) {
            if ($bytes[$i] -eq 13 -and ($i + 1) -lt $bytes.Length -and $bytes[$i + 1] -eq 10) {
                continue
            }
            $outBytes[$w] = $bytes[$i]
            $w++
        }
        $outBytes = $outBytes[0..($w - 1)]
        [System.IO.File]::WriteAllBytes($f, $outBytes)
        $converted++
    }
}
Write-Host "Converted $converted files to LF"
Write-Host "Untouched (not in allowlist): $untouched files"
```

Then stage everything:

```powershell
git add .gitattributes
git add .editorconfig
git add -A
```

## Step 4 — Verify

Re-run the byte-level scan from the diagnosis section. After normalization the expected result is **CRLF=0, Mixed=0** for all allowed extensions.

```powershell
# Quick verification — should show 0 CRLF and 0 Mixed for allowed files
$allowed = @('cs','csx','csproj','slnx','sln','props','targets','xaml','json','http','ts','js','css','html','xml','md','yml','yaml','sh','editorconfig')

$crlf = 0; $mixed = 0; $total = 0
foreach ($f in (git ls-files)) {
    $ext = [System.IO.Path]::GetExtension($f).TrimStart('.')
    $isDotFile = ($f -match '(?i)^(\.gitignore|\.gitattributes|\.editorconfig)$')
    if (-not $isDotFile -and $allowed -notcontains $ext) { continue }

    $total++
    $bytes = [System.IO.File]::ReadAllBytes($f)
    $c = 0; $l = 0
    for ($i = 0; $i -lt $bytes.Length; $i++) {
        if ($bytes[$i] -eq 10) {
            if ($i -gt 0 -and $bytes[$i-1] -eq 13) { $c++ } else { $l++ }
        }
    }
    if ($c -gt 0 -and $l -gt 0) { $mixed++ } elseif ($c -gt 0) { $crlf++ }
}
Write-Host "Checked $total files — CRLF=$crlf  Mixed=$mixed  (should be 0 and 0)"
```

Also verify `.editorconfig` is correct:

```powershell
if (Test-Path .editorconfig) {
    $eol = (Select-String -Path .editorconfig -Pattern 'end_of_line\s*=\s*(\w+)').Matches[0].Groups[1].Value
    Write-Host ".editorconfig end_of_line = $eol"
    if ($eol -ne 'lf') { Write-Host "WARNING: .editorconfig does not enforce LF!" }
} else {
    Write-Host "WARNING: .editorconfig not found — editors will not enforce LF on save."
}
```

Then run the test suite to confirm no regressions were introduced:

```bash
dotnet test   # or the relevant solution/project
```

Line-ending changes should never alter test results — if tests fail after a line-ending-only change, check whether any test reads raw file bytes or compares string literals that include `\r`.

## Step 5 — Commit

```bash
git commit -m "chore: normalize line endings to LF across entire repository

- Add/update .gitattributes with eol=lf for all text file types
- Ensure .editorconfig sets end_of_line = lf in the [*] section
- Normalize N files from CRLF/mixed to LF
- Mark binary files explicitly
- Preserve CRLF for .cmd and .bat files"
```

## How Git EOL settings interact

Understanding the interaction prevents future confusion:

| Setting | Source | Effect |
|---|---|---|
| `core.autocrlf = true` | Global or local config | On checkout: LF→CRLF on Windows. On commit: CRLF→LF. |
| `core.autocrlf = false` | Global or local config | No conversion at all. Files are read/written exactly as stored. |
| `core.eol = lf` | Local config | Forces LF in the working tree regardless of `core.autocrlf`. Do **not** use this as the primary mechanism — `.gitattributes` is the correct approach because it travels with the repo. |
| `*.cs text eol=lf` | `.gitattributes` | **Source of truth for Git.** Git reads this on every commit and checkout. It overrides `core.autocrlf` for the specified patterns. |
| `end_of_line = lf` | `.editorconfig` | **Source of truth for editors.** VS, VS Code, Rider, and other compliant editors use this to decide how to save files. This is what prevents CRLF from creeping back in when a developer saves a file. |

**Priority order for Git (highest wins):**
1. `eol=` in `.gitattributes` — explicit per-pattern
2. `text` in `.gitattributes` — normalize to LF on commit, checkout per `core.autocrlf`
3. `core.autocrlf` — global policy
4. `core.eol` — local override (rarely needed if `.gitattributes` is present)

**The correct setup for a .NET repo:** a committed `.gitattributes` with `eol=lf` for all text extensions **plus** a `.editorconfig` with `end_of_line = lf` in the `[*]` section. The `.gitattributes` handles Git's commit/checkout; the `.editorconfig` handles the editor's save behaviour. Both are needed — one alone is not sufficient. Leave `core.autocrlf` at its default (or `false`) and do **not** set `core.eol` locally; the two committed files make it irrelevant.

## Common pitfalls

1. **`git checkout-index -f -a` does not convert line endings.** It writes the blob contents directly to disk. Use the PowerShell in-place conversion above instead.
2. **`git add --renormalize .` only updates the index.** The working tree files are unchanged until you convert them in place and re-add.
3. **Use an allowlist, not an exclusion list.** An exclusion list (`if ($f -match 'png|jpg|…')`) risks accidentally converting files with unknown binary extensions. An allowlist only touches files you explicitly recognize as text.
4. **`.cmd` and `.bat` files must stay CRLF.** Windows `cmd.exe` cannot parse LF-only batch files. The `.gitattributes` entry `*.cmd text eol=crlf` and their absence from the allowlist handle this.
5. **Never write the conversion back with `[System.IO.File]::WriteAllText($f, $text -replace "`r`n", "`n")`.** On some PowerShell 7.x builds (and Windows PowerShell 5.1) the `-replace` result does not bind to the `(string, char[], Encoding?)` overload and every write fails with `Cannot find an overload for "WriteAllText" and the argument count: "3"` — while the counter keeps incrementing, so the script reports success without having written anything. The byte-level loop in Step 3 is the correct, portable form; it is also immune to BOM damage. See Step 3 for the fix.
6. **Tests that compare string literals containing `\r\n` will fail** after converting test source files. Check for any `Assert.Equal` calls that compare multi-line strings built from file contents. In practice, xUnit test source files that use `\n` in C# verbatim strings (`@"` or raw string literals) are unaffected; only tests that read files with `File.ReadAllText` and compare against a CRLF-containing literal are at risk.
7. **Do not set `core.eol` globally.** It is a per-machine workaround. The `.gitattributes` and `.editorconfig` files are the correct, portable solutions.
8. **A missing `.editorconfig` means editors will keep writing CRLF on Windows** even after you normalize the repo. The normalization is only permanent if the editor is also told to use LF via `.editorconfig`.
