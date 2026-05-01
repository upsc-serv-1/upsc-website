import json
import re
from pathlib import Path

import fitz


ROOT = Path(r"C:\Users\Dr. Yogesh\Downloads\SFG- 2026 - Level 1 codex\upsc-vault-test-v1")
SOL_PATH = Path(r"C:\Users\Dr. Yogesh\Desktop\Final Repo\Test Series\Forum\SFG\SFG- 2026 - Level 1\Test 2 SOL Polity Level 1 SFG 2026.pdf")
OUT_PATH = ROOT / "src" / "data" / "imports" / "forum-sfg-l1-polity-test2.json"


def normalize_text(text: str) -> str:
    replacements = {
        "â€¢": "•",
        "â€“": "–",
        "â€”": "—",
        "â€˜": "‘",
        "â€™": "’",
        'â€œ': "“",
        'â€�': "”",
        "â—": "●",
        "Â ": " ",
        "Â": "",
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    return text


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
        or stripped in {"[1]", "[2]", "[3]", "[4]", "[5]", "[6]", "[7]", "[8]"}
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


def read_lines() -> list[str]:
    doc = fitz.open(SOL_PATH)
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
            plain = line.replace("**", "")
            if plain.startswith("Q."):
                statement_lines.append(re.sub(rf"^Q\.{qno}\)\s*", "", plain).strip())
                continue

            option = re.match(r"^([a-d])\)\s*(.*)", plain)
            if option and current_mode == "question":
                options[option.group(1)] = option.group(2).strip()
                continue

            if plain.startswith("Ans)"):
                answer = plain.split("Ans)", 1)[1].strip()
                current_mode = "answer"
                continue

            if plain.startswith("Exp)"):
                current_mode = "explanation"
                explanation_lines.append(line.strip())
                continue

            if plain.startswith("Source:"):
                current_mode = "source"
                source["sourceText"] = plain.split("Source:", 1)[1].strip()
                continue

            if plain.startswith("Source:)"):
                current_mode = "source"
                source["sourceText"] = plain.split("Source:)", 1)[1].strip()
                continue

            if plain.startswith("Subject:)"):
                source["subject"] = plain.split("Subject:)", 1)[1].strip() or "Polity"
                continue

            if plain.startswith("Topic:)"):
                original_topic_text = plain.split("Topic:)", 1)[1].strip()
                source["topic"] = original_topic_text
                continue

            if plain.startswith("Subtopic:)"):
                source["subtopic"] = plain.split("Subtopic:)", 1)[1].strip()
                continue

            if current_mode == "question":
                statement_lines.append(plain.strip())
            elif current_mode == "explanation":
                explanation_lines.append(line.strip())
            elif current_mode == "source" and source["sourceText"]:
                source["sourceText"] += " " + plain.strip()

        clean_statement_lines = [line.strip() for line in statement_lines if line.strip()]
        question_text = normalize_text(" ".join(clean_statement_lines).replace("  ", " ").strip())
        micro_topic = normalize_text(original_topic_text or "Miscellaneous")
        source["sourceText"] = normalize_text(source["sourceText"].lstrip(") ").strip())
        source["subject"] = normalize_text(source["subject"])
        source["topic"] = normalize_text(source["topic"])
        source["subtopic"] = normalize_text(source["subtopic"])

        questions.append(
            {
                "id": f"forum-sfg-l1-polity-test2-q{qno:02d}",
                "questionNumber": qno,
                "subject": "Polity",
                "sectionGroup": None,
                "microTopic": micro_topic,
                "originalSourceTopic": original_topic_text,
                "isPyq": bool(source["sourceText"]),
                "questionTypeTags": [],
                "statementLines": [normalize_text(line) for line in clean_statement_lines],
                "questionText": question_text,
                "options": options,
                "correctAnswer": answer,
                "explanationMarkdown": normalize_text("\n".join(explanation_lines).strip()),
                "source": source,
            }
        )
    return questions


def main() -> None:
    lines = read_lines()
    questions = parse_questions(lines)
    payload = {
        "id": "forum-sfg-l1-polity-test2",
        "title": "Forum SFG Level 1 • Polity • Test 2",
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
