# CRW Skills

A collection of reusable GitHub Copilot skill packs for practical engineering tasks.

This repository is intentionally lightweight: each skill lives in its own folder under `skills/` and contains a `SKILL.md` file with the instructions, examples, and decision guidance for a specific topic.

## Repository structure

```text
.
├── LICENSE
├── README.md
├── skills/
│   └── net-maui-popups/
│       └── SKILL.md
└── install-skills.bat
```

## How skills are organized

Each skill folder follows the standard Copilot skill pattern:

- a folder under `skills/`
- a `SKILL.md` file at the root of that folder
- YAML front matter with metadata such as `name` and `description`
- markdown instructions and code samples for the target scenario

The current repository includes:

- `net-maui-popups` — .NET MAUI popup and snackbar implementation guidance

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
