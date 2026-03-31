#!/usr/bin/env python3
"""Regenerate .github/prompts/ stubs from the skills in .github/skills/."""
import os
from pathlib import Path


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def generate_prompt(skill_name: str) -> str:
    return (
        f"# Generated file. Edit .github/skills/{skill_name}/SKILL.md instead.\n\n"
        f"Use the `{skill_name}` skill before continuing.\n"
        f"Read `.github/skills/{skill_name}/SKILL.md` and follow it exactly.\n"
    )


def main() -> int:
    root = repo_root()
    skills_dir = root / ".github" / "skills"
    prompts_dir = root / ".github" / "prompts"

    prompts_dir.mkdir(parents=True, exist_ok=True)

    for old_prompt in prompts_dir.glob("*.prompt.md"):
        old_prompt.unlink()

    for skill_dir in sorted(path for path in skills_dir.iterdir() if path.is_dir()):
        prompt_path = prompts_dir / f"use-{skill_dir.name}.prompt.md"
        prompt_path.write_text(generate_prompt(skill_dir.name), encoding="utf-8")

    print("Regenerated .github/prompts/ from .github/skills/.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
