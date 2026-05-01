#!/usr/bin/env python3
"""
Extract questions from Forum Toolkit PYQ Workbook DOCX/MD files.
Converts to website-compatible JSON format.
"""

import json
import re
from pathlib import Path
from typing import Optional

try:
    from docx import Document
except ImportError:
    import subprocess
    subprocess.run(["pip", "install", "python-docx", "-q"], check=True)
    from docx import Document

# Paths
APP_ROOT = Path("C:/Users/Dr. Yogesh/Pictures/website by windsurf")
BOOKS_ROOT = APP_ROOT / "new boks toolkit"
OUTPUT_ROOT = APP_ROOT / "src" / "data" / "imports"
OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)

# Exam pattern regex
EXAM_PATTERNS = [
    (r'\[?\s*UPSC\s+CSE\s*(?:Prelims?|Pre)?\s*(\d{4})\s*\]?', 'UPSC CSE', 'Prelims'),
    (r'\[?\s*UPSC\s+CDS\s*\(?\s*(I{1,3}|IV|V?I{0,3}|1|2)\s*\)?\s*(\d{4})\s*\]?', 'UPSC CDS', None),
    (r'\[?\s*UPSC\s+CAPF\s*(?:AC)?\s*(\d{4})\s*\]?', 'UPSC CAPF', 'CAPF'),
    (r'\[?\s*U\.?P\.?\s*P\.?C\.?\s*S\.?\s*(?:\(?\s*Re\.?\s*Exam\s*\)?)?\s*\(?\s*Pre\s*\)?\s*(\d{4})\s*\]?', 'UPPCS', 'Prelims'),
    (r'\[?\s*B\.?P\.?S\.?C\.?\s*(?:\(?\s*\d{2,3}(?:th|rd|nd)\s*\)?)?\s*(?:\(?\s*Re-?Exam\s*\)?)?\s*\(?\s*Pre\s*\)?\s*(\d{4})\s*\]?', 'BPSC', 'Prelims'),
    (r'\[?\s*R\.?A\.?S\.?/?R\.?T\.?S\.?\s*(?:\(?\s*Pre\s*\)?)?\s*(\d{4})\s*\]?', 'RAS/RTS', 'Prelims'),
    (r'\[?\s*MP\s*P\.?C\.?\s*S\.?\s*(?:\(?\s*Pre\s*\)?)?\s*(\d{4})\s*\]?', 'MPPCS', 'Prelims'),
    (r'\[?\s*UK\s*P\.?C\.?\s*(?:\(?\s*Pre\s*\)?)?\s*(\d{4})\s*\]?', 'UKPCS', 'Prelims'),
    (r'\[?\s*CG\s*P\.?S\.?C\.?\s*(?:\(?\s*Pre\s*\)?)?\s*(\d{4})\s*\]?', 'CGPSC', 'Prelims'),
    (r'\[?\s*Jharkhand\s*P\.?S\.?C\.?\s*(?:\(?\s*Pre\s*\)?)?\s*(\d{4})\s*\]?', 'JPSC', 'Prelims'),
    (r'\[?\s*Haryana\s*P\.?S\.?C\.?\s*(?:\(?\s*Pre\s*\)?)?\s*(\d{4})\s*\]?', 'HPSC', 'Prelims'),
    (r'\[?\s*HP\s*P\.?S\.?C\.?\s*(?:\(?\s*Pre\s*\)?)?\s*(\d{4})\s*\]?', 'HPPSC', 'Prelims'),
    (r'\[?\s*\d{1,2}(?:st|nd|rd|th)?\s*B\.?P\.?S\.?C\.?\s*(?:\(?\s*Re-?Exam\s*\)?)?\s*\(?\s*Pre\s*\)?\s*(\d{4})\s*\]?', 'BPSC', 'Prelims'),
]


def normalize_text(text: str) -> str:
    """Clean and normalize text."""
    if not text:
        return ""
    # Replace mojibake
    replacements = {
        "ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Å“": "–",
        "ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â": "—",
        "Ã¢â‚¬â„¢": "'",
        "Ã¢â‚¬Ëœ": "'",
        "Ã¢â‚¬Å“": '"',
        "Ã¢â‚¬Â": '"',
        "Ã¢â‚¬â€œ": "–",
        "Ã¢â‚¬â€": "—",
        "Ã¢â€”Â": "•",
        "Â°C": "°C",
        "Â": " ",
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    # Clean whitespace
    text = re.sub(r'[ \t]+\n', '\n', text)
    text = re.sub(r'\n{3,}', '\n\n', text)
    text = re.sub(r'[ \t]{2,}', ' ', text)
    return text.strip()


def parse_exam_metadata(text: str) -> tuple[bool, Optional[dict]]:
    """Extract exam metadata from text."""
    text_upper = text.upper()
    
    for pattern, group, exam in EXAM_PATTERNS:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            year = None
            if group == 'UPSC CDS':
                paper = match.group(1).upper()
                year = int(match.group(2)) if len(match.groups()) > 1 and match.group(2) else None
                if paper == '1':
                    paper = 'I'
                elif paper == '2':
                    paper = 'II'
                exam_name = f'CDS {paper}' if paper in {'I', 'II'} else 'CDS'
            else:
                year_match = re.search(r'(\d{4})', text)
                year = int(year_match.group(1)) if year_match else None
                exam_name = exam if exam else 'Prelims'
            
            return True, {
                'group': group,
                'exam': exam_name,
                'year': year
            }
    
    return False, None


def read_docx_paragraphs(filepath: Path) -> list[str]:
    """Read all paragraphs from a DOCX file."""
    doc = Document(filepath)
    paragraphs = []
    for para in doc.paragraphs:
        text = para.text.strip()
        if text:
            paragraphs.append(text)
    return paragraphs


def read_md_file(filepath: Path) -> list[str]:
    """Read all lines from a markdown file."""
    content = filepath.read_text(encoding='utf-8')
    lines = [line.strip() for line in content.split('\n') if line.strip()]
    return lines


def extract_metadata_from_text(text: str) -> dict:
    """Extract Subject, Section, Microtopic from text."""
    metadata = {
        'subject': '',
        'section': '',
        'microtopic': '',
        'original_topic': ''
    }
    
    # Look for metadata patterns
    subject_match = re.search(r'\[?\s*Subject:\s*([^\]]+)\]?', text, re.IGNORECASE)
    if subject_match:
        metadata['subject'] = normalize_text(subject_match.group(1))
    
    section_match = re.search(r'\[?\s*Section:\s*([^\]]+)\]?', text, re.IGNORECASE)
    if section_match:
        metadata['section'] = normalize_text(section_match.group(1))
    
    microtopic_match = re.search(r'\[?\s*Microtopic:\s*([^\]]+)\]?', text, re.IGNORECASE)
    if microtopic_match:
        metadata['microtopic'] = normalize_text(microtopic_match.group(1))
    
    topic_match = re.search(r'\[?\s*Topic:\s*([^\]]+)\]?', text, re.IGNORECASE)
    if topic_match:
        metadata['original_topic'] = normalize_text(topic_match.group(1))
    
    return metadata


def parse_questions_and_solutions(lines: list[str], file_id: str) -> list[dict]:
    """Parse questions and solutions from lines."""
    questions = []
    solutions = {}
    
    # Find all question positions
    question_positions = []
    for idx, line in enumerate(lines):
        # Match question patterns like "1.", "Q1.", "Q1 ", "1 " at start
        match = re.match(r'^(?:Q\.?)?\s*([1-9]\d*)\.?\s+', line)
        if match:
            q_num = int(match.group(1))
            if 1 <= q_num <= 1000:  # Reasonable range
                question_positions.append((idx, q_num, line))
    
    # Find solution patterns
    solution_positions = []
    for idx, line in enumerate(lines):
        # Match solution patterns
        match = re.match(r'^([1-9]\d*)\.\s*Solution', line, re.IGNORECASE)
        if match:
            sol_num = int(match.group(1))
            solution_positions.append((idx, sol_num, line))
    
    print(f"  Found {len(question_positions)} questions, {len(solution_positions)} solutions")
    
    # Parse each question
    for i, (start_idx, q_num, start_line) in enumerate(question_positions):
        # Determine end of this question
        if i + 1 < len(question_positions):
            end_idx = question_positions[i + 1][0]
        else:
            end_idx = len(lines)
        
        # Check if there's a solution for this question
        sol_idx = None
        for s_idx, s_num, s_line in solution_positions:
            if s_num == q_num:
                sol_idx = s_idx
                break
        
        # If solution found, adjust end_idx
        if sol_idx is not None and sol_idx < end_idx:
            question_end = sol_idx
        else:
            question_end = end_idx
            sol_idx = None
        
        # Extract question text
        question_lines = lines[start_idx:question_end]
        
        # Parse question components
        parsed = parse_single_question(q_num, question_lines, file_id)
        if parsed:
            questions.append(parsed)
    
    # Match solutions to questions
    for question in questions:
        q_num = question['questionNumber']
        # Find matching solution
        for s_idx, s_num, s_line in solution_positions:
            if s_num == q_num:
                # Find solution end
                sol_start = s_idx
                if s_idx + 1 < len(solution_positions):
                    sol_end = solution_positions[solution_positions.index((s_idx, s_num, s_line)) + 1][0] if s_idx < len(solution_positions) - 1 else len(lines)
                else:
                    # Find next question or end
                    sol_end = len(lines)
                    for next_q_idx, next_q_num, _ in question_positions:
                        if next_q_num == q_num + 1 and next_q_idx > s_idx:
                            sol_end = next_q_idx
                            break
                
                # Special case: if this is the last solution and there's a next question
                if s_idx == solution_positions[-1][0]:
                    # Solution goes until next question or end
                    for next_q_idx, next_q_num, _ in question_positions:
                        if next_q_num == q_num + 1 and next_q_idx > s_idx:
                            sol_end = next_q_idx
                            break
                
                solution_lines = lines[sol_start:sol_end]
                parsed_sol = parse_solution(q_num, solution_lines)
                if parsed_sol:
                    question['correctAnswer'] = parsed_sol['answer']
                    question['explanationMarkdown'] = parsed_sol['explanation']
                    # Update source text if found in solution
                    if parsed_sol['source_text']:
                        question['source']['sourceText'] = parsed_sol['source_text']
                        # Re-parse PYQ metadata
                        is_pyq, pyq_meta = parse_exam_metadata(parsed_sol['source_text'])
                        question['isPyq'] = is_pyq
                        question['pyqMeta'] = pyq_meta
                break
    
    return questions


def parse_single_question(q_num: int, lines: list[str], file_id: str) -> Optional[dict]:
    """Parse a single question from lines."""
    if not lines:
        return None
    
    # First line is the question header
    first_line = lines[0]
    
    # Remove the question number from first line
    first_line_clean = re.sub(r'^(?:Q\.?)?\s*\d+\.?\s*', '', first_line).strip()
    
    # Collect all text
    all_text = '\n'.join(lines)
    
    # Extract metadata
    metadata = extract_metadata_from_text(all_text)
    
    # Determine subject from file_id if not found
    subject = metadata['subject']
    if not subject:
        if 'polity' in file_id.lower() or 'constitutional' in file_id.lower():
            subject = 'Polity'
        elif 'ancient' in file_id.lower() or 'medieval' in file_id.lower() or 'history' in file_id.lower():
            subject = 'History'
        elif 'art' in file_id.lower() or 'culture' in file_id.lower():
            subject = 'Art and Culture'
    
    # Determine section
    section = metadata['section']
    if not section:
        if 'ancient' in file_id.lower():
            section = 'Ancient History'
        elif 'medieval' in file_id.lower():
            section = 'Medieval History'
        elif 'modern' in file_id.lower():
            section = 'Modern History'
        elif 'art' in file_id.lower() or 'culture' in file_id.lower():
            section = 'Art and Culture'
        elif 'polity' in file_id.lower() or 'constitutional' in file_id.lower():
            section = 'Indian Polity'
    
    # Extract options
    options = {}
    options_found = False
    for i, line in enumerate(lines):
        # Match option patterns: (a), a), A), [a], etc.
        opt_match = re.match(r'^\(?([a-e])\)?[.:\)]\s*(.+)', line, re.IGNORECASE)
        if opt_match:
            opt_letter = opt_match.group(1).lower()
            opt_text = opt_match.group(2).strip()
            options[opt_letter] = normalize_text(opt_text)
            options_found = True
    
    if not options_found:
        # Try alternative format: a., A., a), A)
        for i, line in enumerate(lines):
            opt_match = re.match(r'^([a-e])[.:\)]\s*(.+)', line, re.IGNORECASE)
            if opt_match:
                opt_letter = opt_match.group(1).lower()
                opt_text = opt_match.group(2).strip()
                options[opt_letter] = normalize_text(opt_text)
    
    # Extract statement lines (everything before options)
    statement_lines = []
    current_mode = 'question'
    
    for i, line in enumerate(lines):
        plain = normalize_text(line)
        
        # Check if this is an option
        if re.match(r'^\(?[a-e]\)?[.:\)]', plain, re.IGNORECASE):
            current_mode = 'options'
            continue
        
        if current_mode == 'question':
            # Remove question number from first line
            if i == 0:
                plain = re.sub(r'^(?:Q\.?)?\s*\d+\.?\s*', '', plain)
            if plain:
                statement_lines.append(plain)
    
    # Build question text
    question_text = ' '.join(statement_lines)
    
    # Clean up statement lines
    clean_statement_lines = [line for line in statement_lines if line.strip()]
    
    # Extract source text from the question (usually at the end)
    source_text = ""
    for line in lines:
        # Look for exam patterns
        is_pyq, _ = parse_exam_metadata(line)
        if is_pyq or '[' in line and any(x in line.upper() for x in ['UPSC', 'UPPCS', 'BPSC', 'RAS', 'CDS', 'CAPF']):
            source_text = normalize_text(line)
            break
    
    # Parse PYQ metadata
    is_pyq, pyq_meta = parse_exam_metadata(source_text)
    if not is_pyq:
        is_pyq, pyq_meta = parse_exam_metadata(all_text)
    
    # Determine microtopic
    microtopic = metadata['microtopic']
    if not microtopic:
        microtopic = metadata['original_topic']
    
    question_id = f"{file_id}-q{q_num:03d}"
    
    return {
        'id': question_id,
        'questionNumber': q_num,
        'subject': subject,
        'sectionGroup': section,
        'microTopic': microtopic,
        'originalSourceTopic': metadata['original_topic'],
        'isPyq': is_pyq,
        'pyqMeta': pyq_meta,
        'questionTypeTags': [],
        'statementLines': clean_statement_lines,
        'questionText': normalize_text(question_text),
        'options': options,
        'correctAnswer': '',
        'explanationMarkdown': '',
        'source': {
            'sourceText': source_text,
            'subject': subject,
            'topic': metadata['original_topic'],
            'subtopic': ''
        },
        'questionBlocks': None,
        'questionTable': None
    }


def parse_solution(sol_num: int, lines: list[str]) -> Optional[dict]:
    """Parse solution from lines."""
    if not lines:
        return None
    
    # First line should be "N. Solution (X)"
    first_line = lines[0]
    
    # Extract answer letter
    answer_match = re.search(r'\(([a-e])\)', first_line, re.IGNORECASE)
    answer = answer_match.group(1).lower() if answer_match else ''
    
    # Build explanation
    explanation_lines = []
    source_text = ""
    
    for i, line in enumerate(lines[1:], 1):  # Skip first line
        plain = normalize_text(line)
        
        # Check for source metadata
        if '[' in plain and any(x in plain.upper() for x in ['UPSC', 'UPPCS', 'BPSC', 'RAS', 'CDS', 'CAPF', 'PRE', 'EXAM']):
            source_text = plain
            continue
        
        # Skip metadata lines
        if re.match(r'^\[?(?:Subject|Section|Microtopic|Topic|Year|Hierarchy)', plain, re.IGNORECASE):
            continue
        
        if plain:
            explanation_lines.append(plain)
    
    explanation = '\n'.join(explanation_lines)
    
    # Clean explanation
    explanation = re.sub(r'^Explanation:\s*', '', explanation, flags=re.IGNORECASE)
    
    return {
        'answer': answer,
        'explanation': explanation,
        'source_text': source_text
    }


def process_file(input_path: Path, subject_hint: str, section_hint: str) -> tuple[dict, Path]:
    """Process a single file and return payload and output path."""
    print(f"Processing: {input_path.name}")
    
    # Read file
    if input_path.suffix.lower() == '.docx':
        lines = read_docx_paragraphs(input_path)
    elif input_path.suffix.lower() == '.md':
        lines = read_md_file(input_path)
    else:
        raise ValueError(f"Unsupported file type: {input_path.suffix}")
    
    print(f"  Read {len(lines)} lines")
    
    # Generate file ID from filename
    file_id_base = re.sub(r'[^a-z0-9]', '-', input_path.stem.lower())
    file_id_base = re.sub(r'-+', '-', file_id_base).strip('-')
    
    # Parse questions
    questions = parse_questions_and_solutions(lines, file_id_base)
    
    print(f"  Parsed {len(questions)} questions")
    
    # Determine subject and section from filename
    filename_lower = input_path.name.lower()
    subject = subject_hint
    section = section_hint
    
    # Build title
    title_parts = [part for part in file_id_base.split('-') if part]
    title = ' '.join(title_parts[:5]).title()
    
    # Build payload
    payload = {
        'id': file_id_base,
        'title': f"Forum Toolkit • {title}",
        'provider': 'Forum Toolkit PYQ Workbook',
        'series': 'PYQ Workbook',
        'level': 'Book',
        'year': 2026,
        'subject': subject,
        'sectionGroup': section,
        'paperType': 'Question Bank',
        'defaultMinutes': 0,
        'sourceMode': 'docx-sol',
        'questions': questions
    }
    
    # Output path
    out_path = OUTPUT_ROOT / f"{file_id_base}.json"
    
    return payload, out_path


def write_payload(payload: dict, out_path: Path) -> None:
    """Write payload to JSON file."""
    out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f"  Written: {out_path}")


def main():
    """Process all files in the books toolkit."""
    all_files = []
    
    # Ancient/Art/Culture/Medieval History
    ancient_dir = BOOKS_ROOT / "ancient, art and culture, medieval history"
    if ancient_dir.exists():
        for f in ancient_dir.iterdir():
            if f.suffix.lower() in ['.docx', '.md']:
                subject = 'Art and Culture' if 'art' in f.name.lower() or 'culture' in f.name.lower() else 'History'
                section = 'Ancient History' if 'ancient' in f.name.lower() else ('Medieval History' if 'medieval' in f.name.lower() else 'Art and Culture')
                all_files.append((f, subject, section))
    
    # Modern History
    modern_dir = BOOKS_ROOT / "modern history"
    if modern_dir.exists():
        for f in modern_dir.iterdir():
            if f.suffix.lower() in ['.docx', '.md']:
                all_files.append((f, 'History', 'Modern History'))
    
    # Polity
    polity_dir = BOOKS_ROOT / "polity"
    if polity_dir.exists():
        for f in polity_dir.iterdir():
            if f.suffix.lower() in ['.docx', '.md']:
                all_files.append((f, 'Polity', 'Indian Polity'))
    
    # Economy
    economy_dir = BOOKS_ROOT / "economy"
    if economy_dir.exists():
        for f in economy_dir.iterdir():
            if f.suffix.lower() in ['.docx', '.md']:
                all_files.append((f, 'Economy', 'Indian Economy'))
    
    # Geography
    geography_dir = BOOKS_ROOT / "geography"
    if geography_dir.exists():
        for f in geography_dir.iterdir():
            if f.suffix.lower() in ['.docx', '.md']:
                section = 'Physical Geography'
                if 'economic' in f.name.lower():
                    section = 'Economic Geography'
                elif 'india' in f.name.lower():
                    section = 'Indian Geography'
                elif 'world' in f.name.lower():
                    section = 'World Geography'
                all_files.append((f, 'Geography', section))
    
    # Prisma PYQ Books
    prisma_dir = BOOKS_ROOT / "prisma pyq books"
    if prisma_dir.exists():
        for f in prisma_dir.iterdir():
            if f.suffix.lower() in ['.docx', '.md']:
                fname = f.name.lower()
                if 'polity' in fname:
                    all_files.append((f, 'Polity', 'Indian Polity'))
                elif 'ancient' in fname:
                    all_files.append((f, 'History', 'Ancient History'))
                elif 'medieval' in fname:
                    all_files.append((f, 'History', 'Medieval History'))
                elif 'modern' in fname:
                    all_files.append((f, 'History', 'Modern History'))
                elif 'art' in fname or 'culture' in fname:
                    all_files.append((f, 'Art and Culture', 'Art and Culture'))
                elif 'economy' in fname:
                    all_files.append((f, 'Economy', 'Indian Economy'))
                elif 'geography' in fname or 'geog' in fname:
                    section = 'Indian Geography' if 'india' in fname else 'World Geography'
                    all_files.append((f, 'Geography', section))
                elif 'environment' in fname:
                    all_files.append((f, 'Environment', 'Environment and Ecology'))
                elif 'science' in fname:
                    all_files.append((f, 'Science and Technology', 'General Science'))
                else:
                    all_files.append((f, 'General Studies', 'Miscellaneous'))
    
    print(f"\nFound {len(all_files)} files to process\n")
    
    processed = 0
    errors = []
    
    for filepath, subject, section in all_files:
        try:
            payload, out_path = process_file(filepath, subject, section)
            write_payload(payload, out_path)
            processed += 1
        except Exception as e:
            errors.append((filepath.name, str(e)))
            print(f"  ERROR: {e}")
    
    print(f"\n{'='*50}")
    print(f"Processing complete: {processed}/{len(all_files)} files")
    if errors:
        print(f"Errors: {len(errors)}")
        for name, err in errors:
            print(f"  - {name}: {err}")


if __name__ == "__main__":
    main()
