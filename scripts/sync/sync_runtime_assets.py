#!/usr/bin/env python3
import os
import shutil
from pathlib import Path


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def reset_dir(path: Path) -> None:
    if path.exists():
        shutil.rmtree(path, onexc=clear_readonly)
    path.mkdir(parents=True, exist_ok=True)


def clear_readonly(func, path, _exc_info) -> None:
    os.chmod(path, 0o700)
    func(path)


def copy_tree(src: Path, dst: Path) -> None:
    reset_dir(dst)
    shutil.copytree(src, dst, dirs_exist_ok=True)


def generate_prompt(skill_name: str) -> str:
    return (
        f"# Generated file. Edit resources/skills/{skill_name}/SKILL.md instead.\n\n"
        f"Use the `{skill_name}` skill before continuing.\n"
        f"Read `.github/skills/{skill_name}/SKILL.md` and follow it exactly.\n"
    )


def main() -> int:
    root = repo_root()
    resources = root / "resources"

    skills_src = resources / "skills"
    skills_dst = root / ".github" / "skills"
    prompts_dst = root / ".github" / "prompts"
    hooks_src = resources / "hooks"
    hooks_dst = root / "scripts" / "hooks"

    copy_tree(skills_src, skills_dst)
    copy_tree(hooks_src, hooks_dst)

    prompts_dst.mkdir(parents=True, exist_ok=True)
    for old_prompt in prompts_dst.glob("*.prompt.md"):
        old_prompt.unlink()

    for skill_dir in sorted(path for path in skills_src.iterdir() if path.is_dir()):
        prompt_path = prompts_dst / f"use-{skill_dir.name}.prompt.md"
        prompt_path.write_text(generate_prompt(skill_dir.name), encoding="utf-8")

    print("Synced runtime assets from resources/ into .github/ and scripts/hooks/.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
