"""
Extract questions from each PRISMA section
"""
import re
import json

# Read the extracted text
with open('C:/Users/Dr. Yogesh/Pictures/polity pyq workbook/prisma_extracted.txt', 'r', encoding='utf-8') as f:
    text = f.read()

# Based on the analysis, identify section boundaries by looking for Q1 patterns and context
# Ancient: starts around first Q1 (line 449)
# Art & Culture: after Ancient (need to find)
# Medieval: after Art & Culture
# Modern: after Medieval (around line 201472)
# World Geography: after Modern questions end
# Indian Geography: after World Geography
# Environment: after Indian Geography (around line 196027)

def extract_questions_from_section(text, start_marker, end_marker=None):
    """Extract questions from a section of text"""
    questions = []
    
    # Find section boundaries
    start_pos = text.find(start_marker)
    if start_pos == -1:
        return questions
    
    if end_marker:
        end_pos = text.find(end_marker, start_pos)
        if end_pos == -1:
            section_text = text[start_pos:]
        else:
            section_text = text[start_pos:end_pos]
    else:
        section_text = text[start_pos:]
    
    # Pattern to match questions: Q[num]. followed by question text, options, and Answer
    # Also capture PYQ info if present
    question_pattern = r'Q(\d+)\.\s*(.*?)\s*\(a\)\s*(.*?)\s*\(b\)\s*(.*?)\s*\(c\)\s*(.*?)\s*\(d\)\s*(.*?)(?:\(e\)\s*(.*?))?\s*Answer:\s*\(([a-d])\)'
    
    matches = list(re.finditer(question_pattern, section_text, re.DOTALL))
    
    for i, match in enumerate(matches):
        q_num = match.group(1)
        q_text = match.group(2).strip()
        option_a = match.group(3).strip()
        option_b = match.group(4).strip()
        option_c = match.group(5).strip()
        option_d = match.group(6).strip()
        option_e = match.group(7).strip() if match.group(7) else None
        answer = match.group(8)
        
        # Clean up question text (remove page markers, etc.)
        q_text = re.sub(r'\.{3,}', '', q_text)
        q_text = re.sub(r'\s+', ' ', q_text)
        
        # Look for PYQ info in question text
        pyq_match = re.search(r'\[UPSC\s+CSE.*?\d{4}.*?\]', q_text, re.IGNORECASE)
        is_pyq = pyq_match is not None
        
        question = {
            'num': int(q_num),
            'text': q_text,
            'options': {
                'a': option_a,
                'b': option_b,
                'c': option_c,
                'd': option_d,
            },
            'answer': answer,
            'is_pyq': is_pyq,
            'pyq_info': pyq_match.group(0) if pyq_match else None
        }
        
        if option_e:
            question['options']['e'] = option_e
        
        questions.append(question)
    
    return questions

# Test extraction on Ancient section first
ancient_start = text.find("Q1. The Palaeolithic age")
if ancient_start == -1:
    ancient_start = text.find("Q1.")

print(f"Ancient section starts at position: {ancient_start}")
print(f"Preview: {text[ancient_start:ancient_start+200]}")

# Let's manually look at the structure around the first Q1
lines = text.split('\n')
for i, line in enumerate(lines[:500]):
    if 'Q1.' in line:
        print(f"Line {i}: {line[:100]}")
        # Show next 10 lines for context
        for j in range(i, min(i+15, len(lines))):
            print(f"  {j}: {lines[j][:80]}")
        break
