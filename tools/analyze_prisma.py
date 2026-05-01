# Read the extracted text
with open('C:/Users/Dr. Yogesh/Pictures/polity pyq workbook/prisma_extracted.txt', 'r', encoding='utf-8') as f:
    lines = f.readlines()

print("Searching for section headers and question patterns...")

# Look for section headers
sections = []
for i, line in enumerate(lines):
    line = line.strip()
    # Look for section headers like "Ancient", "Medieval", "Modern", "Art & Culture", etc.
    if line in ["Ancient", "Medieval", "Modern", "Art & Culture", "World Geography", "Indian Geography", "Environment"]:
        sections.append((i, line))
    # Also look for combined patterns
    elif "Ancient" in line and len(line) < 50:
        sections.append((i, line))
    elif "Medieval" in line and len(line) < 50:
        sections.append((i, line))
    elif "Modern" in line and len(line) < 50 and "Modern" not in "Modern India":
        sections.append((i, line))

print(f"\nFound {len(sections)} potential section markers:")
for idx, section in sections[:20]:
    print(f"  Line {idx}: {section}")

# Look for question patterns
question_lines = []
for i, line in enumerate(lines[:5000]):  # Check first 5000 lines
    if line.strip().startswith('Q') and '.' in line[:10]:
        question_lines.append((i, line.strip()))

print(f"\n\nFound {len(question_lines)} potential questions in first 5000 lines:")
for idx, q in question_lines[:20]:
    print(f"  Line {idx}: {q[:60]}")
