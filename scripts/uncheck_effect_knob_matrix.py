#!/usr/bin/env python3
"""Uncheck IMPLEMENTATION_PLAN matrix rows for skills with active Effect Knobs."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUDIT_PATH = ROOT / "reports" / "effect_knob_audit_lines.txt"
CONTRACT_PATH = ROOT / "tests" / "extra_rules_conversion_contract.gd"
PLAN_PATH = ROOT / "IMPLEMENTATION_PLAN.md"
FACTORY_DIR = ROOT / "core" / "factory" / "classes"

CHECKED_COLS = "| ☑ | ☑ | ☑ | ☑ |"
UNCHECKED_COLS = "| ☐ | ☐ | ☐ | ☐ |"
NOTE_SUFFIX = " **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete."

MATRIX_ALIASES: dict[str, str | None] = {
    "Impale / Run Down": "lancer_run_down",
    "Wraparound / Flanking Maneuver": "lancer_flanking_maneuver",
    "Caltrops": "archer_caltrop_trap",
    "Fetch / Snatch": "beast_fetch",
    "Rest and Recover": "beast_rest_recover",
    "Flank & Run": "mercenary_flank_and_run",
    "Riposte": "mercenary_riposte_strike",
    "Executioner's Blade": "mercenary_executioners_blade",
    "Duelist's Challenge": "mercenary_duelists_challenge",
    "Martyr's Chains": "cleric_martyrs_chains",
    "Reactive Adrenaline": None,  # passive row — not an active Effect Knob skill
}


def normalize_apostrophe(text: str) -> str:
    return text.replace("\u2019", "'").replace("\u2018", "'").strip()


def load_audit() -> dict[str, int]:
    audit: dict[str, int] = {}
    for line in AUDIT_PATH.read_text(encoding="utf-8").splitlines():
        match = re.search(r"(\w+):\s*typed_extras=(\d+)", line)
        if match:
            audit[match.group(1)] = int(match.group(2))
    return audit


def load_converted_skill_ids() -> set[str]:
    text = CONTRACT_PATH.read_text(encoding="utf-8")
    ids = re.findall(r'&"([^"]+)"', text)
    class_ids = {
        "knight",
        "bruiser",
        "archer",
        "lancer",
        "mage",
        "cleric",
        "mercenary",
        "monk",
        "rogue",
        "beast_rider",
        "engineer",
        "shaman",
    }
    return {skill_id for skill_id in ids if skill_id not in class_ids}


def load_display_name_to_id(converted_ids: set[str]) -> dict[str, str]:
    mapping: dict[str, str] = {}
    for factory_path in FACTORY_DIR.glob("*_factory.gd"):
        text = factory_path.read_text(encoding="utf-8")
        for match in re.finditer(r'&"([a-z0-9_]+)",\s*"([^"]+)"', text):
            skill_id, display = match.group(1), match.group(2)
            if skill_id not in converted_ids:
                continue
            mapping[display] = skill_id
            mapping[normalize_apostrophe(display)] = skill_id
            mapping[display.lower()] = skill_id
    for alias, skill_id in MATRIX_ALIASES.items():
        if skill_id is not None:
            mapping[alias] = skill_id
            mapping[normalize_apostrophe(alias)] = skill_id
    return mapping


def resolve_skill_id(skill_name: str, name_to_id: dict[str, str]) -> str | None:
    skill_name = normalize_apostrophe(skill_name)
    if skill_name in MATRIX_ALIASES:
        return MATRIX_ALIASES[skill_name]
    if skill_name in name_to_id:
        return name_to_id[skill_name]
    lowered = skill_name.lower()
    if lowered in name_to_id:
        return name_to_id[lowered]
    return None


def uncheck_matrix_row(line: str) -> str:
    if CHECKED_COLS not in line:
        return line
    parts = line.rstrip("\n").split("|")
    if len(parts) < 9:
        return line.replace(CHECKED_COLS, UNCHECKED_COLS)
    parts[3] = " ☐ "
    parts[4] = " ☐ "
    parts[5] = " ☐ "
    parts[6] = " ☐ "
    note = parts[7].strip()
    if NOTE_SUFFIX.strip() not in note:
        parts[7] = f" {note}{NOTE_SUFFIX} "
    return "|".join(parts) + "\n"


def main() -> None:
    converted_ids = load_converted_skill_ids()
    audit = load_audit()
    knob_ids = {skill_id for skill_id, count in audit.items() if count > 0}
    name_to_id = load_display_name_to_id(converted_ids)

    lines = PLAN_PATH.read_text(encoding="utf-8").splitlines(keepends=True)
    start = next(i for i, line in enumerate(lines) if line.startswith("| Knight | Defensive Formation"))
    end = next(
        i
        for i, line in enumerate(lines)
        if i > start and line.startswith("**Matrix completion rule:**")
    )

    unchecked_matrix = 0
    unresolved: list[str] = []
    for index in range(start, end):
        line = lines[index]
        if not line.startswith("|") or line.startswith("|---") or "Class | Skill" in line:
            continue
        parts = [part.strip() for part in line.split("|")]
        if len(parts) < 8:
            continue
        skill_name = parts[2]
        skill_id = resolve_skill_id(skill_name, name_to_id)
        if skill_id is None:
            unresolved.append(skill_name)
            continue
        if skill_id not in knob_ids:
            continue
        new_line = uncheck_matrix_row(line)
        if new_line != line:
            lines[index] = new_line
            unchecked_matrix += 1

  # Checklist items
    unchecked_checklist = 0
    for index, line in enumerate(lines):
        stripped = line.strip()
        if not stripped.startswith("- [x]"):
            continue
        for skill_id in knob_ids:
            if f"`{skill_id}`" in line:
                new_line = line.replace("- [x]", "- [ ]", 1)
                if "Effect Knobs" not in new_line:
                    new_line = new_line.rstrip("\n") + " — **UNCHECKED:** Effect Knobs active.\n"
                lines[index] = new_line
                unchecked_checklist += 1
                break

    for index, line in enumerate(lines):
        if line.startswith("**Matrix completion rule:**"):
            lines[index] = (
                "**Matrix completion rule (2026-08-22):** Check all four columns only after "
                "shape gate passes for that skill (**zero** active Effect Knobs unless matrix "
                "explicitly allows ER-1 **New field** only). Rows marked **UNCHECKED** had false "
                "PASS from ownership-only QA. Re-check after real module/layer refactor.\n"
            )
            break

    PLAN_PATH.write_text("".join(lines), encoding="utf-8")
    print(f"Effect Knob skills: {len(knob_ids)}")
    print(f"Matrix rows unchecked: {unchecked_matrix}")
    print(f"Checklist lines unchecked: {unchecked_checklist}")
    if unresolved:
        print("Unresolved matrix skill names:")
        for name in unresolved:
            print(f"  - {name}")
    zero_knob = sorted(skill_id for skill_id, count in audit.items() if count == 0)
    print(f"Still checked (zero Effect Knobs): {len(zero_knob)}")


if __name__ == "__main__":
    main()
