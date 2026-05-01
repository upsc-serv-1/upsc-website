import json
import re
from pathlib import Path

import fitz


APP_ROOT = next(
    parent
    for parent in Path(__file__).resolve().parents
    if parent.name == "upsc-vault-test-v1"
)
WORKSPACE_ROOT = APP_ROOT.parent
OUT_PATH = APP_ROOT / "src" / "data" / "imports" / "forum-sfg-l1-polity-test3.json"

SOL_NAME = "Test 3 SOL Polity Level 1 SFG 2026.pdf"

BODY_TOPIC_BY_QUESTION = {
    1: "Constitutional Bodies",
    10: "Constitutional Bodies",
    11: "Non-Constitutional Bodies",
    15: "Non-Constitutional Bodies",
    20: "Federal System",
    21: "Non-Constitutional Bodies",
    26: "Constitutional Bodies",
    27: "Constitutional Bodies",
    28: "Non-Constitutional Bodies",
    29: "Non-Constitutional Bodies",
    30: "Constitutional Bodies",
    31: "Constitutional Bodies",
    32: "Constitutional Bodies",
    33: "Constitutional Bodies",
    34: "Miscellaneous",
    36: "Miscellaneous",
    37: "Miscellaneous",
    40: "Non-Constitutional Bodies",
    43: "Non-Constitutional Bodies",
    45: "Miscellaneous",
    47: "Miscellaneous",
    49: "Non-Constitutional Bodies",
    50: "Non-Constitutional Bodies",
}

SOURCE_TOPIC_MAP = {
    "Nature of Federalism": "Federal System",
    "Centre State Relations- legislative, administrative and Financial": "Federal System",
    "Inter-State Relations": "Federal System",
    "Special Provisions/Areas": "Federal System",
}

MOJIBAKE_REPLACEMENTS = {
    "Ã¢â‚¬â€œ": "–",
    "Ã¢â‚¬â€": "—",
    "Ã¢â‚¬Ëœ": "‘",
    "Ã¢â‚¬â„¢": "’",
    "Ã¢â‚¬Å“": "“",
    "Ã¢â‚¬ï¿½": "”",
    "â€™": "’",
    "â€˜": "‘",
    "â€œ": "“",
    "â€": "”",
    "â€“": "–",
    "â€”": "—",
    "â€¢": "•",
    "â—": "•",
    "â€": "\"",
    "Ã—": "×",
    "Ã‚ ": " ",
    "Ã‚": "",
}


def find_sol_path() -> Path:
    matches = list(WORKSPACE_ROOT.rglob(SOL_NAME))
    if not matches:
        raise FileNotFoundError(f"Could not find {SOL_NAME!r} under {WORKSPACE_ROOT}")
    return max(matches, key=lambda path: path.stat().st_mtime)


def normalize_text(text: str) -> str:
    for old, new in MOJIBAKE_REPLACEMENTS.items():
        text = text.replace(old, new)
    text = re.sub(r"[ \t]+\n", "\n", text)
    text = re.sub(r"[ \t]{2,}", " ", text)
    return text.strip()


def is_header_or_footer(line: str) -> bool:
    stripped = line.replace("**", "").strip()
    return (
        not stripped
        or stripped.startswith("SFG 2026 |")
        or stripped.startswith("Forum Learning Centre:")
        or stripped.startswith("9311740400")
        or "Canal Road, Patna" in stripped
        or "Jawahar Nagar, Hyderabad" in stripped
        or "academy.forumias.com" in stripped
        or re.fullmatch(r"\[\d+\]", stripped) is not None
    )


def render_line(line_dict: dict) -> str:
    parts = []
    for span in line_dict["spans"]:
        text = span["text"]
        if not text:
            continue
        is_bold = ("Bold" in (span.get("font") or "")) or (span.get("flags", 0) & 16)
        parts.append(f"**{text}**" if is_bold else text)
    line = "".join(parts).strip()
    line = re.sub(r"\*\*([^\*]+)\*\*\*\*([^\*]+)\*\*", r"**\1\2**", line)
    return normalize_text(line)


def read_lines(sol_path: Path) -> list[str]:
    doc = fitz.open(sol_path)
    lines = []
    for page in doc:
        data = page.get_text("dict")
        for block in data["blocks"]:
            if "lines" not in block:
                continue
            for line_dict in block["lines"]:
                line = render_line(line_dict)
                if not is_header_or_footer(line):
                    lines.append(line)
    return lines


def canonical_micro_topic(qno: int, source_topic: str) -> str:
    topic = normalize_text(source_topic)
    if topic == "Constitutional and Non-Constitutional Bodies":
        return BODY_TOPIC_BY_QUESTION.get(qno, "Miscellaneous")
    if topic in SOURCE_TOPIC_MAP:
        if qno == 41:
            return "Salient Features"
        return SOURCE_TOPIC_MAP[topic]
    if not topic:
        return "Federal System" if qno == 12 else "Miscellaneous"
    return topic


def parse_pyq_meta(source_text: str) -> tuple[bool, dict | None]:
    clean_source = normalize_text(source_text)
    if "UPSC" not in clean_source.upper():
        return False, None

    year_match = re.search(r"(20\d{2}|19\d{2})", clean_source)
    year = int(year_match.group(1)) if year_match else None
    upper = clean_source.upper()

    if "UPSC CSE" in upper:
        return True, {"group": "UPSC CSE", "exam": "Prelims", "year": year}

    if "UPSC CDS" in upper:
        paper_match = re.search(r"[\[\(]?\s*(I{1,3}|IV|V?I{0,3}|1|2)\s*[\]\)]?", clean_source)
        paper = paper_match.group(1).upper() if paper_match else ""
        if paper == "1":
            paper = "I"
        elif paper == "2":
            paper = "II"
        exam = f"CDS {paper}" if paper in {"I", "II"} else "CDS"
        return True, {"group": "UPSC CDS", "exam": exam, "year": year}

    if "UPSC CAPF" in upper:
        return True, {"group": "UPSC CAPF", "exam": "CAPF", "year": year}

    return False, None


def parse_questions(lines: list[str]) -> list[dict]:
    starts = []
    for idx, line in enumerate(lines):
        plain = line.replace("**", "")
        match = re.match(r"Q\.(\d+)\)\s*(.*)", plain)
        if match:
            starts.append((idx, int(match.group(1))))

    questions = []
    for pos, (start_idx, qno) in enumerate(starts):
        end_idx = starts[pos + 1][0] if pos + 1 < len(starts) else len(lines)
        chunk = lines[start_idx:end_idx]

        statement_lines = []
        options = {}
        answer = ""
        explanation_lines = []
        source = {"sourceText": "", "subject": "Polity", "topic": "", "subtopic": ""}
        original_topic_text = ""
        current_mode = "question"

        for line in chunk:
            plain = normalize_text(line.replace("**", ""))
            if plain.startswith(f"Q.{qno})"):
                statement_lines.append(normalize_text(re.sub(rf"^Q\.{qno}\)\s*", "", plain)))
                continue

            option = re.match(r"^([a-d])\)\s*(.*)", plain)
            if option and current_mode == "question":
                options[option.group(1)] = normalize_text(option.group(2))
                continue

            if plain.startswith("Ans)"):
                answer = normalize_text(plain.split("Ans)", 1)[1])
                current_mode = "answer"
                continue

            if plain.startswith("Exp)"):
                current_mode = "explanation"
                explanation_lines.append(line.strip())
                continue

            if plain.startswith("Source:)"):
                current_mode = "source"
                source["sourceText"] = normalize_text(plain.split("Source:)", 1)[1])
                continue

            if plain.startswith("Source:"):
                current_mode = "source"
                source["sourceText"] = normalize_text(plain.split("Source:", 1)[1])
                continue

            if plain.startswith("Subject:)"):
                source["subject"] = normalize_text(plain.split("Subject:)", 1)[1] or "Polity")
                continue

            if plain.startswith("Topic:)"):
                original_topic_text = normalize_text(plain.split("Topic:)", 1)[1])
                source["topic"] = original_topic_text
                continue

            if plain.startswith("Subtopic:)"):
                source["subtopic"] = normalize_text(plain.split("Subtopic:)", 1)[1])
                continue

            if current_mode == "question":
                statement_lines.append(plain)
            elif current_mode == "explanation":
                explanation_lines.append(line.strip())
            elif current_mode == "source" and source["sourceText"]:
                source["sourceText"] = normalize_text(f'{source["sourceText"]} {plain}')

        clean_statement_lines = [normalize_text(line) for line in statement_lines if normalize_text(line)]
        question_text = normalize_text(" ".join(clean_statement_lines))
        explanation_markdown = normalize_text("\n".join(explanation_lines))
        source = {key: normalize_text(value) for key, value in source.items()}
        source["subject"] = source["subject"] or "Polity"
        source["sourceText"] = source["sourceText"].lstrip(") ").strip()

        is_pyq, pyq_meta = parse_pyq_meta(source["sourceText"])

        question = {
            "id": f"forum-sfg-l1-polity-test3-q{qno:02d}",
            "questionNumber": qno,
            "subject": "Polity",
            "sectionGroup": None,
            "microTopic": canonical_micro_topic(qno, original_topic_text),
            "originalSourceTopic": original_topic_text,
            "isPyq": is_pyq,
            "pyqMeta": pyq_meta,
            "questionTypeTags": [],
            "statementLines": clean_statement_lines,
            "questionText": question_text,
            "options": options,
            "correctAnswer": answer,
            "explanationMarkdown": explanation_markdown,
            "source": source,
        }

        if len(options) != 4:
            raise ValueError(f"Question {qno} does not have exactly four options.")
        questions.append(question)

    if len(questions) != 50:
        raise ValueError(f"Expected 50 questions, found {len(questions)}.")
    return questions


def main() -> None:
    sol_path = find_sol_path()
    lines = read_lines(sol_path)
    questions = parse_questions(lines)
    payload = {
        "id": "forum-sfg-l1-polity-test3",
        "title": "Forum SFG Level 1 • Polity • Test 3",
        "provider": "Forum SFG Level 1",
        "series": "SFG",
        "level": "Level 1",
        "year": 2026,
        "subject": "Polity",
        "sectionGroup": None,
        "paperType": "Sectional",
        "defaultMinutes": 60,
        "sourceMode": "sol-only",
        "questions": questions,
    }
    OUT_PATH.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(OUT_PATH)


if __name__ == "__main__":
    main()
