from __future__ import annotations

import argparse
import os
import shutil
from pathlib import Path

from skill_library import SKILL_ORDER, SKILLS, repo_root_from_skills, skills_root_from_script


def build_prompt_file(slug: str) -> str:
    skill = SKILLS[slug]
    return (
        "---\n"
        "agent: 'agent'\n"
        f"description: '{skill['short_description']}'\n"
        "---\n\n"
        f"Read `.github/skills/{slug}/SKILL.md` and follow that skill for this task.\n"
        f"Only load files under `.github/skills/{slug}/references/` if they are relevant.\n\n"
        "Task: ${input:task:Describe the task for this skill}\n"
        "Context: ${input:context:Optional files, specs, tickets, or constraints}\n"
    )


def build_kiro_steering(slug: str, skill_dir: Path) -> str:
    skill = SKILLS[slug]
    reference_lines = []
    refs_dir = skill_dir / "references"
    if refs_dir.exists():
        for ref in sorted(refs_dir.glob("*.md")):
            reference_lines.append(
                f"- `#[[file:.github/skills/{slug}/references/{ref.name}]]` - load only when the task needs that detail."
            )

    lines = [
        f"# {skill['display_name']}",
        "",
        skill["description"],
        "",
        "Primary instructions:",
        f"- `#[[file:.github/skills/{slug}/SKILL.md]]`",
    ]
    if reference_lines:
        lines.extend(["", "Optional references:"])
        lines.extend(reference_lines)
    return "\n".join(lines).rstrip() + "\n"


def reset_dir(path: Path) -> None:
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True, exist_ok=True)


def sync_copilot(skills_root: Path, repo_root: Path) -> None:
    skills_target = repo_root / ".github" / "skills"
    prompts_target = repo_root / ".github" / "prompts"
    reset_dir(skills_target)
    reset_dir(prompts_target)

    for slug in SKILL_ORDER:
        shutil.copytree(skills_root / slug, skills_target / slug)
        (prompts_target / f"use-{slug}.prompt.md").write_text(
            build_prompt_file(slug),
            encoding="utf-8",
        )


def sync_kiro(skills_root: Path, repo_root: Path) -> None:
    steering_target = repo_root / ".kiro" / "steering"
    reset_dir(steering_target)
    for slug in SKILL_ORDER:
        (steering_target / f"{slug}.md").write_text(
            build_kiro_steering(slug, skills_root / slug),
            encoding="utf-8",
        )


def sync_codex(skills_root: Path, codex_target: Path) -> None:
    codex_target.mkdir(parents=True, exist_ok=True)
    for slug in SKILL_ORDER:
        destination = codex_target / slug
        if destination.exists():
            shutil.rmtree(destination)
        shutil.copytree(skills_root / slug, destination)


def default_codex_target() -> Path:
    codex_home = os.environ.get("CODEX_HOME")
    if codex_home:
        return Path(codex_home) / "skills"
    return Path.home() / ".codex" / "skills"


def main() -> None:
    parser = argparse.ArgumentParser(description="Sync canonical skills to runtime targets.")
    parser.add_argument(
        "--target",
        choices=["all", "copilot", "kiro", "codex"],
        default="all",
        help="Runtime target to sync.",
    )
    parser.add_argument(
        "--codex-target",
        type=Path,
        default=None,
        help="Override Codex install path. Defaults to CODEX_HOME/skills or ~/.codex/skills.",
    )
    args = parser.parse_args()

    skills_root = skills_root_from_script(Path(__file__))
    repo_root = repo_root_from_skills(skills_root)

    if args.target in {"all", "copilot"}:
        sync_copilot(skills_root, repo_root)
    if args.target in {"all", "kiro"}:
        sync_kiro(skills_root, repo_root)
    if args.target in {"all", "codex"}:
        sync_codex(skills_root, args.codex_target or default_codex_target())


if __name__ == "__main__":
    main()
