# CRW Skills

A collection of reusable GitHub Copilot skill packs for practical engineering tasks.

This repository is intentionally lightweight: each skill lives in its own folder under `skills/` and contains a `SKILL.md` file with the instructions, examples, and decision guidance for a specific topic.

## Repository structure

```text
.
├── LICENSE
├── README.md
├── skills/
│   ├── net-maui-custom-control/
│   │   └── SKILL.md
│   ├── net-maui-popups/
│   │   └── SKILL.md
│   └── net-maui-skiasharp/
│       └── SKILL.md
├── showcases/
│   ├── net-maui-custom-control/
│   │   └── create-all-controls.md
│   ├── net-maui-popups/
│   │   └── create-all-popups.md
│   └── net-maui-skiasharp/
│       └── create-skiasharp-showcase.md
└── install-skills.bat
```

## How skills are organized

Each skill folder follows the standard Copilot skill pattern:

- a folder under `skills/`
- a `SKILL.md` file at the root of that folder
- YAML front matter with metadata such as `name` and `description`
- markdown instructions and code samples for the target scenario

The current repository includes:

- `net-maui-custom-control` — .NET MAUI custom control design and implementation guidance (base-class choice by semantic role, BindableProperty, ControlTemplate, XAML vs C#, when to defer to SkiaSharp)
- `net-maui-popups` — .NET MAUI popup and snackbar implementation guidance
- `net-maui-skiasharp` — .NET MAUI custom 2D rendering with SkiaSharp 4.x (SKCanvasView vs SKGLView, coordinate systems, invalidation/animation, resource reuse, 4.x API rules)

## Validation showcases

Each skill has a matching task under `showcases/` used to validate the skill text: a blank MAUI project is created in `E:\temp` (`dotnet new maui`), the showcase is implemented strictly from the skill, and the project is compiled. The validation run should produce clear feedback on the skill's contents.

- `showcases/net-maui-custom-control/create-all-controls.md` — one compact control per base-class category, all on one page
- `showcases/net-maui-popups/create-all-popups.md` — one button per popup pattern
- `showcases/net-maui-skiasharp/create-skiasharp-showcase.md` — three small animated/interactive SkiaSharp controls

## Skill format and spec reference

The structure is aligned with the GitHub Copilot skill convention used for repository-scoped guidance files: a folder containing a `SKILL.md` with metadata plus implementation instructions. In practice, this means the skill package is easy to copy into a local skills directory and use as a reusable prompt source for project-specific work.

If you want to keep the repo aligned with the broader Copilot conventions, the useful rule is:

- keep one skill per concern
- keep the folder name stable and descriptive
- write the instructions as task-oriented guidance, not as a general essay
- include quick decision rules and concrete code examples

## Local install

From the repository root, run the installer to copy the skill definitions into the local skills directory used by your tooling:

```bat
install-skills.bat
```

This keeps the repository as the source of truth while making the skills available in the environment your agent tools read.

Some tools support user-global skill folders such as `.agent`, but that behavior is tool-specific rather than a universal GitHub Copilot standard.

## Notes

This repo is meant to hold reusable, domain-specific guidance that can be shared across multiple projects without duplicating implementation details. The contents should stay focused, opinionated, and easy to follow.
