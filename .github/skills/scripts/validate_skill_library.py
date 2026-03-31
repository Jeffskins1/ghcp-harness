from __future__ import annotations

import re
import sys
from pathlib import Path

from skill_library import SKILL_ORDER, repo_root_from_skills, skills_root_from_script


FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---\n", re.DOTALL)


def fail(message: str) -> None:
    print(f"ERROR: {message}")
    raise SystemExit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def main() -> None:
    skills_root = skills_root_from_script(Path(__file__))
    repo_root = repo_root_from_skills(skills_root)

    for slug in SKILL_ORDER:
        skill_dir = skills_root / slug
        skill_file = skill_dir / "SKILL.md"
        openai_file = skill_dir / "agents" / "openai.yaml"
        require(skill_dir.is_dir(), f"Missing skill directory: {skill_dir}")
        require(skill_file.is_file(), f"Missing SKILL.md: {skill_file}")
        require(openai_file.is_file(), f"Missing OpenAI metadata: {openai_file}")

        skill_text = skill_file.read_text(encoding="utf-8")
        frontmatter_match = FRONTMATTER_RE.match(skill_text)
        require(frontmatter_match is not None, f"Missing frontmatter in {skill_file}")
        frontmatter = frontmatter_match.group(1)
        require(f"name: {slug}" in frontmatter, f"Frontmatter name mismatch in {skill_file}")
        require("description:" in frontmatter, f"Missing description in {skill_file}")

        for match in re.finditer(r"`(references/[^`]+)`", skill_text):
            rel_path = match.group(1)
            require((skill_dir / rel_path).is_file(), f"Broken reference {rel_path} in {skill_file}")

        yaml_text = openai_file.read_text(encoding="utf-8")
        require("display_name:" in yaml_text, f"Missing display_name in {openai_file}")
        require("short_description:" in yaml_text, f"Missing short_description in {openai_file}")
        require(
            f"$%s" % slug in yaml_text,
            f"default_prompt must mention ${slug} in {openai_file}",
        )

    for slug in SKILL_ORDER:
        prompt_file = repo_root / ".github" / "prompts" / f"use-{slug}.prompt.md"
        steering_file = repo_root / ".kiro" / "steering" / f"{slug}.md"
        copilot_skill = repo_root / ".github" / "skills" / slug / "SKILL.md"
        require(prompt_file.is_file(), f"Missing Copilot prompt file: {prompt_file}")
        require(steering_file.is_file(), f"Missing Kiro steering file: {steering_file}")
        require(copilot_skill.is_file(), f"Missing Copilot skill package: {copilot_skill}")

    print("Skill library validation passed.")


if __name__ == "__main__":
    main()
