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

MOJIBAKE_REPLACEMENTS = {
    "ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Å“": "–",
    "ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â": "—",
    "ÃƒÂ¢Ã¢â€šÂ¬Ã‹Å“": "‘",
    "ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢": "’",
    "ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œ": "“",
    "ÃƒÂ¢Ã¢â€šÂ¬Ã¯Â¿Â½": "”",
    "Ã¢â‚¬â„¢": "’",
    "Ã¢â‚¬Ëœ": "‘",
    "Ã¢â‚¬Å“": "“",
    "Ã¢â‚¬Â": "”",
    "Ã¢â‚¬â€œ": "–",
    "Ã¢â‚¬â€": "—",
    "Ã¢â‚¬Â¢": "•",
    "Ã¢â€”Â": "•",
    "Ã¢â‚¬": "\"",
    "Ãƒâ€”": "×",
    "Ãƒâ€š ": " ",
    "Ãƒâ€š": "",
}


def normalize_text(text: str) -> str:
    for old, new in MOJIBAKE_REPLACEMENTS.items():
        text = text.replace(old, new)
    text = re.sub(r"[ \t]+\n", "\n", text)
    text = re.sub(r"[ \t]{2,}", " ", text)
    return text.strip()


def clean_explanation_markdown(text: str) -> str:
    text = normalize_text(text)
    text = re.sub(r"\n([a-dA-D]\))\s*\n", r"\n\1 ", text)
    text = re.sub(r"\n(\([a-dA-D]\))\s*\n", r"\n\1 ", text)
    text = re.sub(r"\n([•◦▪●➤➢\-])\s*\n", r"\n\1 ", text)

    markers = [
        r"Statement\s+[IVX0-9]+(?:\s+is\s+(?:correct|incorrect)(?:\s+but\s+does\s+not\s+appropriately\s+explain\s+Statement\s+[IVX0-9]+)?)?:",
        r"Option\s+[A-ZIVX0-9]+(?:\s+is\s+(?:correct|incorrect))?:",
        r"Ans\)",
        r"Exp\)",
        r"Source:",
        r"Subject:\)?",
        r"Topic:\)?",
        r"Subtopic:\)?",
    ]
    for marker in markers:
        text = re.sub(rf"\s*({marker})", r"\n\1", text)

    text = re.sub(r"\*\*\s*\n\s*(Statement\s+[IVX0-9]+)", r"\n**\1", text)
    text = re.sub(r"\*\*\s*\n\s*(Option\s+[A-ZIVX0-9]+)", r"\n**\1", text)
    text = re.sub(r"\n\s*\*\*\s*$", "", text, flags=re.MULTILINE)

    lines = [line.strip() for line in text.splitlines()]
    output = []
    current = ""

    def flush():
        nonlocal current
        if current:
            output.append(current.strip())
            current = ""

    structured_re = re.compile(
        r"^(Exp\)|Ans\)|Source:|Subject:\)?|Topic:\)?|Subtopic:\)?|Statement\s+[IVX0-9]+|Option\s+[A-ZIVX0-9]+|[•◦▪●➤➢\-]\s+|[a-dA-D]\)\s+|\([a-dA-D]\)\s+)"
    )

    for line in lines:
        if not line:
            flush()
            continue
        if structured_re.match(line):
            flush()
            output.append(line)
            continue
        if current:
            current = f"{current} {line}"
        else:
            current = line

    flush()
    cleaned = "\n".join(output)
    cleaned = re.sub(r"\n{3,}", "\n\n", cleaned)
    cleaned = re.sub(r" +", " ", cleaned)
    return cleaned.strip()


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


def find_pdf(pdf_name: str) -> Path:
    matches = list(WORKSPACE_ROOT.rglob(pdf_name))
    if not matches:
        raise FileNotFoundError(f"Could not find {pdf_name!r} under {WORKSPACE_ROOT}")
    return max(matches, key=lambda path: path.stat().st_mtime)


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
        paper_match = re.search(r"UPSC\s+CDS\s*[\[\(]?\s*(I{1,3}|IV|V?I{0,3}|1|2)\s*[\]\)]?", clean_source, re.I)
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


def parse_questions(
    lines: list[str],
    test_id: str,
    topic_mapper,
) -> list[dict]:
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
        explanation_markdown = clean_explanation_markdown("\n".join(explanation_lines))
        source = {key: normalize_text(value) for key, value in source.items()}
        source["subject"] = source["subject"] or "Polity"
        source["sourceText"] = source["sourceText"].lstrip(") ").strip()

        is_pyq, pyq_meta = parse_pyq_meta(source["sourceText"])

        question = {
            "id": f"{test_id}-q{qno:02d}",
            "questionNumber": qno,
            "subject": "Polity",
            "sectionGroup": None,
            "microTopic": topic_mapper(qno, original_topic_text, question_text, source),
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


def build_payload(test_number: int, sol_name: str, topic_mapper) -> tuple[dict, Path]:
    sol_path = find_pdf(sol_name)
    lines = read_lines(sol_path)
    test_id = f"forum-sfg-l1-polity-test{test_number}"
    questions = parse_questions(lines, test_id, topic_mapper)
    payload = {
        "id": test_id,
        "title": f"Forum SFG Level 1 • Polity • Test {test_number}",
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
    out_path = APP_ROOT / "src" / "data" / "imports" / f"{test_id}.json"
    return payload, out_path


def write_payload(payload: dict, out_path: Path) -> None:
    out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
