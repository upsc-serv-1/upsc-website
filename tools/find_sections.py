"""
Find actual section content by looking for question patterns
"""

# Read the extracted text
with open('C:/Users/Dr. Yogesh/Pictures/polity pyq workbook/prisma_extracted.txt', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find all Q1. occurrences - these mark the start of each question set
q1_positions = []
for i, line in enumerate(lines):
    if line.strip().startswith('Q1.') and len(line.strip()) < 200:
        # Look at context to confirm it's a question start
        context = ''.join(lines[i:i+5])
        if '(a)' in context or '(b)' in context:
            q1_positions.append((i, line.strip()))

print(f"Found {len(q1_positions)} Q1. markers:")
for pos, text in q1_positions:
    print(f"  Line {pos}: {text[:70]}")

# Look for "INDIAN HISTORY" or subject headers
print("\n\nLooking for subject headers:")
for i, line in enumerate(lines):
    line_upper = line.strip().upper()
    if line_upper in ["INDIAN HISTORY", "HISTORY", "GEOGRAPHY", "WORLD GEOGRAPHY", "INDIAN GEOGRAPHY", "ENVIRONMENT"]:
        print(f"  Line {i}: {line.strip()}")

# Look for "POLITY" in Part 2 reference to understand structure
print("\n\nLooking for Part 2 reference (Polity, Economy):")
for i, line in enumerate(lines):
    if "POLITY" in line or "Part-2" in line or "ECONOMY" in line:
        print(f"  Line {i}: {line.strip()[:70]}")
