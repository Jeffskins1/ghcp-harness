from __future__ import annotations

import re
import shutil
from pathlib import Path

from skill_library import (
    DROP_SECTIONS,
    REFERENCE_EXTRACTIONS,
    SKILL_ORDER,
    SKILLS,
    repo_root_from_skills,
    skills_root_from_script,
)


SECTION_RE = re.compile(r"(?m)^##\s+(.+?)\s*$")
METADATA_RE = re.compile(r"^(Trigger|Output|Duration|Phase):\s*(.*)$")
EXTRACTED_HEADING_RE = re.compile(r"^##\s+.+?\n+", re.DOTALL)
REFERENCE_DUPLICATE_HEADING_RE = re.compile(r"(?s)\A(# .+?\n\n)## .+?\n\n")


NORMALIZE_MAP = {
    "—": "-",
    "–": "-",
    "→": "->",
    "⚠": "Warning:",
    "✓": "[done]",
    "•": "-",
    "’": "'",
    "“": '"',
    "”": '"',
    "…": "...",
    "â€”": "-",
    "â€“": "-",
    "â†’": "->",
    "âš ": "Warning:",
    "âœ“": "[done]",
    "â€¢": "-",
}


def parse_header(source: str) -> tuple[dict[str, str], str]:
    marker = source.find("\n## ")
    if marker == -1:
        raise ValueError("Expected at least one level-2 heading in source skill")
    header = source[:marker].splitlines()
    body = source[marker + 1 :]
    metadata: dict[str, str] = {}
    current_key: str | None = None

    for raw_line in header:
        if not raw_line.startswith("#"):
            continue
        line = raw_line.lstrip("#").strip()
        if not line or line == "SKILL METADATA":
            continue
        match = METADATA_RE.match(line)
        if match:
            current_key = match.group(1)
            metadata[current_key] = match.group(2).strip()
            continue
        if current_key and line.startswith(("Use ", "Run ", "For ", "rather than", "or the", "when ")):
            metadata[current_key] = f"{metadata[current_key]} {line}".strip()
            continue
        if current_key and raw_line.startswith("#            "):
            metadata[current_key] = f"{metadata[current_key]} {line}".strip()

    return metadata, body


def split_sections(body: str) -> list[tuple[str, str]]:
    matches = list(SECTION_RE.finditer(body))
    sections: list[tuple[str, str]] = []
    for index, match in enumerate(matches):
        start = match.start()
        end = matches[index + 1].start() if index + 1 < len(matches) else len(body)
        heading = match.group(1).strip()
        sections.append((heading, body[start:end].strip()))
    return sections


def replace_skill_refs(text: str) -> str:
    for slug in SKILL_ORDER:
        text = text.replace(f"`{slug}.md`", f"`{slug}`")
        text = text.replace(f"{slug}.md", slug)
    return text


def normalize_text(text: str) -> str:
    normalized = text
    for source, target in NORMALIZE_MAP.items():
        normalized = normalized.replace(source, target)
    return normalized


def build_reference_file(target: Path, title: str, chunks: list[str]) -> None:
    content = [f"# {title}", ""]
    for chunk in chunks:
        normalized = EXTRACTED_HEADING_RE.sub("", chunk.strip(), count=1)
        normalized = normalize_text(normalized)
        if normalized:
            content.append(normalized)
            content.append("")
    target.write_text("\n".join(content).rstrip() + "\n", encoding="utf-8")


def build_skill_body(
    slug: str,
    metadata: dict[str, str],
    sections: list[tuple[str, str]],
    references: list[tuple[str, str]],
) -> str:
    skill = SKILLS[slug]
    lines = [
        "---",
        f"name: {slug}",
        f"description: {skill['description']}",
        "---",
        "",
        f"# {skill['display_name']}",
        "",
        "## Overview",
        "",
        skill["description"],
        "",
        "## Quick Reference",
        "",
    ]

    quick_reference = [
        ("Use when", metadata.get("Trigger")),
        ("Output", metadata.get("Output")),
        ("Duration", metadata.get("Duration")),
        ("Phase", metadata.get("Phase")),
    ]
    for label, value in quick_reference:
        if value:
            lines.append(
                f"- **{label}:** {normalize_text(replace_skill_refs(' '.join(value.split())))}"
            )
    lines.append("")

    if references:
        lines.extend(["## Bundled Resources", ""])
        for rel_path, description in references:
            lines.append(f"- `{rel_path}`: {description}")
        lines.append("")

    for _, section_text in sections:
        lines.append(normalize_text(replace_skill_refs(section_text)))
        lines.append("")

    return normalize_text("\n".join(lines).rstrip()) + "\n"


def build_openai_yaml(slug: str) -> str:
    skill = SKILLS[slug]
    return (
        "interface:\n"
        f'  display_name: "{skill["display_name"]}"\n'
        f'  short_description: "{skill["short_description"]}"\n'
        f'  default_prompt: "{skill["default_prompt"]}"\n'
        "\n"
        "policy:\n"
        "  allow_implicit_invocation: true\n"
    )


def build_legacy_alias(slug: str) -> str:
    skill = SKILLS[slug]
    return (
        f"# Legacy Alias: {skill['display_name']}\n\n"
        "This compatibility entry now points to the canonical skill package at "
        f"`.github/skills/{slug}/SKILL.md`.\n\n"
        f"Use the `{slug}` skill name in Codex/OpenAI and Copilot skill runtimes. "
        f"For GitHub Copilot prompt-file workflows, use `/use-{slug}`.\n"
    )


def normalize_existing_skill(target_dir: Path) -> None:
    skill_file = target_dir / "SKILL.md"
    skill_file.write_text(normalize_text(skill_file.read_text(encoding="utf-8")), encoding="utf-8")

    references_dir = target_dir / "references"
    if references_dir.exists():
        for ref_file in references_dir.glob("*.md"):
            ref_text = ref_file.read_text(encoding="utf-8")
            ref_text = normalize_text(ref_text)
            ref_text = REFERENCE_DUPLICATE_HEADING_RE.sub(r"\1", ref_text, count=1)
            ref_file.write_text(ref_text, encoding="utf-8")


def rewrite_readme(skills_root: Path) -> None:
    lines = [
        "# ICTT Skills Library",
        "",
        "This directory contains canonical multi-agent skill packages for the ICTT workflow.",
        "Each canonical skill now lives in `.github/skills/<skill-name>/SKILL.md`.",
        "",
        "## Canonical Skills",
        "",
    ]
    for slug in SKILL_ORDER:
        lines.append(f"- `{slug}/` - {SKILLS[slug]['description']}")
    lines.extend(
        [
            "",
            "## Generated Runtime Targets",
            "",
            "- `.github/skills/` - Copilot agent-skill packages",
            "- `.github/prompts/` - Copilot prompt-file wrappers for IDE workflows",
            "- `.kiro/steering/` - Kiro steering adapters that point back to the canonical skills",
            "- `scripts/sync_agent_skills.py` - syncs the canonical source to runtime targets and optional Codex install locations",
            "",
            "## Compatibility",
            "",
            "- Root-level `*.md` files are retained as legacy aliases that point to the canonical folders.",
            "- Prefer linking to `.github/skills/<skill-name>/SKILL.md` in new docs and prompts.",
        ]
    )
    (skills_root / "README.md").write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def rewrite_repo_paths(repo_root: Path) -> None:
    text_extensions = {".md", ".html", ".json", ".sh", ".ps1", ".txt", ".yml", ".yaml"}
    for path in repo_root.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in text_extensions:
            continue
        try:
            original = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        updated = original
        for slug in SKILL_ORDER:
            updated = updated.replace(
                f".github/skills/{slug}.md",
                f".github/skills/{slug}/SKILL.md",
            )
        if updated != original:
            path.write_text(updated, encoding="utf-8")


def main() -> None:
    skills_root = skills_root_from_script(Path(__file__))
    repo_root = repo_root_from_skills(skills_root)

    for slug in SKILL_ORDER:
        source_path = skills_root / f"{slug}.md"
        target_dir = skills_root / slug
        if not source_path.exists():
            raise FileNotFoundError(f"Missing legacy source file: {source_path}")
        source = source_path.read_text(encoding="utf-8")
        if source.startswith("# Legacy Alias:"):
            if not (target_dir / "SKILL.md").exists():
                raise FileNotFoundError(f"Missing canonical skill file: {target_dir / 'SKILL.md'}")
            normalize_existing_skill(target_dir)
            source_path.write_text(build_legacy_alias(slug), encoding="utf-8")
            continue
        metadata, body = parse_header(source)
        raw_sections = split_sections(body)
        extraction_plan = REFERENCE_EXTRACTIONS.get(slug, {})
        drop_sections = DROP_SECTIONS.get(slug, set())

        if target_dir.exists():
            shutil.rmtree(target_dir)
        (target_dir / "agents").mkdir(parents=True)

        extracted_chunks: dict[str, list[str]] = {}
        extracted_titles: dict[str, str] = {}
        references: list[tuple[str, str]] = []
        kept_sections: list[tuple[str, str]] = []

        for heading, section_text in raw_sections:
            if heading in extraction_plan:
                spec = extraction_plan[heading]
                ref_name = spec["filename"]
                extracted_chunks.setdefault(ref_name, []).append(section_text)
                extracted_titles[ref_name] = spec["title"]
                if (f"references/{ref_name}", spec["description"]) not in references:
                    references.append((f"references/{ref_name}", spec["description"]))
                continue
            if heading in drop_sections:
                continue
            kept_sections.append((heading, section_text))

        if references:
            (target_dir / "references").mkdir(exist_ok=True)
            for ref_name, chunks in extracted_chunks.items():
                build_reference_file(
                    target_dir / "references" / ref_name,
                    extracted_titles[ref_name],
                    [replace_skill_refs(chunk) for chunk in chunks],
                )

        (target_dir / "SKILL.md").write_text(
            build_skill_body(slug, metadata, kept_sections, references),
            encoding="utf-8",
        )
        (target_dir / "agents" / "openai.yaml").write_text(
            build_openai_yaml(slug),
            encoding="utf-8",
        )
        source_path.write_text(build_legacy_alias(slug), encoding="utf-8")

    rewrite_readme(skills_root)
    rewrite_repo_paths(repo_root)


if __name__ == "__main__":
    main()
