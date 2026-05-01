"""
Parse PRISMA sections by identifying start/end positions
"""
import re

# Read the extracted text
with open('C:/Users/Dr. Yogesh/Pictures/polity pyq workbook/prisma_extracted.txt', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find section boundaries
sections = {
    "Ancient": {"start": None, "end": None},
    "Art & Culture": {"start": None, "end": None},
    "Medieval": {"start": None, "end": None},
    "Modern": {"start": None, "end": None},
    "World Geography": {"start": None, "end": None},
    "Indian Geography": {"start": None, "end": None},
    "Environment": {"start": None, "end": None}
}

# Look for section headers in the text
for i, line in enumerate(lines):
    line_stripped = line.strip()
    
    # Ancient section (starts around line 383 based on index)
    if line_stripped == "Ancient" or line_stripped.startswith("Ancient ....."):
        sections["Ancient"]["start"] = i
    
    # Art & Culture
    elif line_stripped == "Art & Culture" or line_stripped.startswith("Art & Culture......"):
        sections["Art & Culture"]["start"] = i
    
    # Medieval
    elif line_stripped == "Medieval" or line_stripped.startswith("Medieval......"):
        sections["Medieval"]["start"] = i
    
    # Modern
    elif line_stripped == "Modern" or line_stripped.startswith("Modern ........"):
        sections["Modern"]["start"] = i
    
    # World Geography
    elif line_stripped == "World Geography" or line_stripped.startswith("World Geography....."):
        sections["World Geography"]["start"] = i
    
    # Indian Geography
    elif line_stripped == "Indian Geography" or line_stripped.startswith("Indian Geography......."):
        sections["Indian Geography"]["start"] = i
    
    # Environment
    elif line_stripped == "Environment" or line_stripped.startswith("ENVIRONMENT....."):
        sections["Environment"]["start"] = i

print("Section start positions found:")
for section, positions in sections.items():
    print(f"  {section}: Line {positions['start']}")

# Calculate end positions (each section ends where the next begins)
section_names = ["Ancient", "Art & Culture", "Medieval", "Modern", "World Geography", "Indian Geography", "Environment"]
for i in range(len(section_names) - 1):
    current = section_names[i]
    next_section = section_names[i + 1]
    if sections[current]["start"] and sections[next_section]["start"]:
        sections[current]["end"] = sections[next_section]["start"]

# Last section ends at end of file
sections["Environment"]["end"] = len(lines)

print("\nSection boundaries:")
for section, positions in sections.items():
    if positions["start"] and positions["end"]:
        print(f"  {section}: Lines {positions['start']} - {positions['end']}")
    else:
        print(f"  {section}: INCOMPLETE - Start: {positions['start']}, End: {positions['end']}")

# Save section info
with open('C:/Users/Dr. Yogesh/Pictures/polity pyq workbook/prisma_sections.txt', 'w', encoding='utf-8') as f:
    for section, positions in sections.items():
        f.write(f"{section}: {positions['start']} - {positions['end']}\n")

print("\nSection info saved to prisma_sections.txt")
