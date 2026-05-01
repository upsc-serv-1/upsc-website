"""
Main PRISMA JSON Builder - Creates all 7 JSON files with proper structure
"""
import json
import re
import uuid

# Read the extracted text
with open('C:/Users/Dr. Yogesh/Pictures/polity pyq workbook/prisma_extracted.txt', 'r', encoding='utf-8') as f:
    lines = f.readlines()

def parse_question_block(lines, start_idx):
    """Parse a single question starting at given index"""
    if start_idx >= len(lines):
        return None, start_idx
    
    line = lines[start_idx].strip()
    
    # Check if this is a question start
    q_match = re.match(r'Q(\d+)\.\s*(.*)', line)
    if not q_match:
        return None, start_idx + 1
    
    q_num = int(q_match.group(1))
    q_text_lines = [q_match.group(2)] if q_match.group(2) else []
    
    options = {}
    answer = None
    in_options = False
    current_option = None
    
    i = start_idx + 1
    while i < len(lines):
        line = lines[i].strip()
        
        # Check for answer
        ans_match = re.match(r'Answer:\s*\(([a-d])\)', line, re.IGNORECASE)
        if ans_match:
            answer = ans_match.group(1)
            i += 1
            break
        
        # Check for options
        opt_match = re.match(r'\(([a-e])\)\s*(.*)', line)
        if opt_match:
            opt_letter = opt_match.group(1)
            opt_text = opt_match.group(2)
            options[opt_letter] = opt_text
            in_options = True
            current_option = opt_letter
        elif in_options and current_option and line:
            # Continue previous option text
            options[current_option] += ' ' + line
        elif line and not in_options and len(q_text_lines) < 20:  # Limit question text lines
            q_text_lines.append(line)
        
        i += 1
    
    if answer and len(options) >= 4:
        q_text = ' '.join(q_text_lines).strip()
        # Clean up question text
        q_text = re.sub(r'\s+', ' ', q_text)
        
        return {
            'num': q_num,
            'text': q_text,
            'options': options,
            'answer': answer
        }, i
    
    return None, i

def detect_pyq_info(text):
    """Detect PYQ information from question text"""
    patterns = [
        r'\[UPSC\s+CSE.*?\d{4}.*?\]',
        r'\[CDS.*?\d{4}.*?\]',
        r'\[CAPF.*?\d{4}.*?\]',
        r'\[IAS.*?\d{4}.*?\]',
        r'\[UPPCS.*?\d{4}.*?\]',
        r'\[BPSC.*?\d{4}.*?\]'
    ]
    
    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            pyq_str = match.group(0)
            # Parse PYQ info
            year_match = re.search(r'(\d{4})', pyq_str)
            year = int(year_match.group(1)) if year_match else None
            
            if 'UPSC' in pyq_str.upper():
                return {'group': 'UPSC', 'exam': 'CSE Prelims', 'year': year}
            elif 'CDS' in pyq_str.upper():
                return {'group': 'CDS', 'exam': 'CDS', 'year': year}
            elif 'CAPF' in pyq_str.upper():
                return {'group': 'CAPF', 'exam': 'CAPF', 'year': year}
            elif 'UPPCS' in pyq_str.upper():
                return {'group': 'UPPCS', 'exam': 'UPPCS', 'year': year}
            elif 'BPSC' in pyq_str.upper():
                return {'group': 'BPSC', 'exam': 'BPSC', 'year': year}
    
    return None

def assign_micro_topic(q_text, subject, section_group):
    """Assign micro-topic based on user's hierarchy"""
    text_lower = q_text.lower()
    
    # Ancient History
    if subject == "History" and section_group == "Ancient":
        if any(x in text_lower for x in ['indus', 'harappa', 'mohenjo', 'daro']):
            return "Indus Valley Civilization"
        elif any(x in text_lower for x in ['vedic', 'rigveda', 'upanishad', 'arya']):
            return "Vedic Age"
        elif any(x in text_lower for x in ['buddha', 'buddhist', 'jain', 'mahavira']):
            return "Buddhism, Jainism & Other Philosophies"
        elif any(x in text_lower for x in ['maurya', 'chandragupta', 'ashoka', 'kautilya']):
            return "Mauryan Empire"
        elif any(x in text_lower for x in ['gupta', 'kalidasa', 'samudra gupta']):
            return "Gupta Period"
        elif any(x in text_lower for x in ['sangam', 'tamil', 'chola', 'pandya']):
            return "Sangam Age"
        return "Literature of Ancient India"
    
    # Medieval History
    elif subject == "History" and section_group == "Medieval":
        if any(x in text_lower for x in ['mughal', 'babur', 'akbar', 'jahangir', 'aurangzeb']):
            return "Mughals & Sur Empire"
        elif any(x in text_lower for x in ['delhi sultanate', 'khilji', 'tughlaq']):
            return "Delhi Sultanate & Early Muslim Invasions"
        elif any(x in text_lower for x in ['vijayanagara', 'bahmani']):
            return "Vijayanagara Empire & Bahmani Kingdom"
        elif any(x in text_lower for x in ['maratha', 'shivaji']):
            return "Maratha Empire"
        return "Major Dynasties of Early Medieval India"
    
    # Modern History
    elif subject == "History" and section_group == "Modern":
        if any(x in text_lower for x in ['1857', 'revolt', 'mutiny']):
            return "1857 Revolt - Resistance & Revolt"
        elif any(x in text_lower for x in ['gandhi', 'non-cooperation', 'civil disobedience']):
            return "Gandhian Phase (Post-1917 till Partition, including NCM, CDM, QIM, Simon Commission, etc.)"
        elif any(x in text_lower for x in ['independence', '1947', 'partition']):
            return "Partition & Independence"
        return "Early National Movement - Moderates, Extremists"
    
    # Art & Culture
    elif subject == "History" and section_group == "Art & Culture":
        if any(x in text_lower for x in ['temple', 'stupa', 'cave', 'ajanta']):
            return "Architecture"
        elif any(x in text_lower for x in ['sculpture', 'bronze', 'terracotta']):
            return "Sculpture"
        elif any(x in text_lower for x in ['painting', 'mural', 'miniature']):
            return "Painting"
        return "Literature"
    
    # Geography - World
    elif subject == "Geography" and section_group == "World Geography":
        if any(x in text_lower for x in ['mountain', 'plateau', 'peak']):
            return "Mountains, Plateaus, Valleys"
        elif any(x in text_lower for x in ['river', 'lake']):
            return "Rivers, Lakes"
        elif any(x in text_lower for x in ['desert', 'sahara']):
            return "Deserts"
        elif any(x in text_lower for x in ['strait', 'ocean', 'sea']):
            return "Straits, Channels, Oceans, Seas, Gulfs, Bays"
        return "Mountains, Plateaus, Valleys"
    
    # Geography - Indian
    elif subject == "Geography" and section_group == "Indian Geography":
        if any(x in text_lower for x in ['himalaya', 'ghat', 'thar']):
            return "Physiography of India (Location, Division, Physiographic Regions)"
        elif any(x in text_lower for x in ['river', 'ganga', 'yamuna', 'brahmaputra']):
            return "Drainage System, Rivers, River Interlinking"
        elif any(x in text_lower for x in ['monsoon', 'climate']):
            return "Climate, Monsoon"
        return "Physiography of India (Location, Division, Physiographic Regions)"
    
    # Environment
    return "Ecology and Ecosystem"

# Process Ancient History (first ~65 questions based on index)
print("Processing Ancient History...")
ancient_questions = []
start_idx = 449  # Line where Q1 starts

while start_idx < len(lines) and len(ancient_questions) < 70:
    q_data, next_idx = parse_question_block(lines, start_idx)
    if q_data:
        ancient_questions.append(q_data)
        start_idx = next_idx
    else:
        start_idx += 1

print(f"Extracted {len(ancient_questions)} Ancient questions")

# Save sample
with open('C:/Users/Dr. Yogesh/Pictures/polity pyq workbook/ancient_sample.json', 'w', encoding='utf-8') as f:
    json.dump(ancient_questions[:3], f, indent=2, ensure_ascii=False)

print("Sample saved to ancient_sample.json")
