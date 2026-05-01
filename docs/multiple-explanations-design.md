# Multiple Explanations Per Question - Design Document

## Overview
This document outlines the design for supporting multiple explanations per question from different sources (e.g., Forama IS, Prisma IS, Forum IAS). This feature will allow users to switch between different explanation sources when viewing a question.

## Requirements
1. Questions can have multiple explanations from different sources (e.g., Prisma IS, Forum IAS)
2. Users can choose which explanation source to view (Prisma IS, Forum IAS, etc.)
3. UPSC official papers (which only have correct answers) can have multiple explanations attached
4. Backward compatibility with existing single-explanation questions
5. No breaking changes to existing import functionality

## Current JSON Format (Existing)
Based on reference JSON file, current structure:
```json
{
  "id": "forum-toolkit-geography-unit3-oceanography",
  "title": "Forum Toolkit Geography PYQ Workbook • Unit 3 • Oceanography",
  "provider": "Forum Toolkit Geography PYQ Workbook",
  "series": "PYQ Workbook",
  "level": "Book",
  "year": 2026,
  "subject": "Geography",
  "sectionGroup": "Physical Geography - Oceanography",
  "paperType": "Question Bank",
  "defaultMinutes": 0,
  "sourceMode": "docx-sol",
  "questions": [
    {
      "id": "forum-toolkit-geography-unit3-oceanography-q001",
      "questionNumber": 1,
      "subject": "Geography",
      "sectionGroup": "Physical Geography - Oceanography",
      "microTopic": "Temperature, Salinity",
      "isPyq": true,
      "pyqMeta": {
        "group": "UPSC CSE",
        "exam": "Prelims",
        "year": 2023
      },
      "statementLines": ["Statement-I...", "Statement-II..."],
      "questionText": "Question text...",
      "options": {
        "a": "Option A",
        "b": "Option B",
        "c": "Option C",
        "d": "Option D"
      },
      "correctAnswer": "d",
      "explanationMarkdown": "**Exp) Option d is the correct answer.**\nDetailed explanation...",
      "source": {
        "sourceText": "UPSC CSE Pre 2023",
        "subject": "Geography",
        "topic": "Temperature, Salinity",
        "subtopic": ""
      }
    }
  ]
}
```

## Word Document Format (Source Format)
The Word documents have solutions labeled by source:
```
Q898. In which one of the following regions was Dhanyakataka...?
•	a) Andhra
•	b) Gandhara
•	c) Kalinga
•	d) Magadha
[Year: 2023 | Exam: UPSC CSE Pre 2023] [Source: Prisma + Forum]

Solution (Prisma IAS):
•	*Exp)** **Option a is the correct answer.**
•	Amaravati in Andhra Pradesh holds historical significance...
•	Hence, option (a) is the correct answer.
Correct Answer: a

Solution (Forum IAS):
•	*Exp) Option a is the correct answer.**
•	Dharanikota is a town near Amaravati in the Guntur district...
[Subject: History] [Section: Ancient] [Microtopic: Post-Mauryan Period]
```

## New JSON Format (Backward Compatible)

### Format with Multiple Explanations
```json
{
  "id": "upsc-prelims-2025-gs1",
  "title": "UPSC CSE Prelims 2025 GS Paper 1",
  "provider": "UPSC Official",
  "subject": "General Studies",
  "questions": [
    {
      "id": "q1",
      "questionNumber": 1,
      "questionText": "Question text here...",
      "options": {
        "a": "Option A",
        "b": "Option B",
        "c": "Option C",
        "d": "Option D"
      },
      "correctAnswer": "a",
      // Keep existing field for backward compatibility
      "explanationMarkdown": "**Exp) Option a is the correct answer.**\nDefault explanation...",
      // New field for multiple explanations
      "explanations": [
        {
          "source": "Prisma IAS",
          "markdown": "**Exp) Option a is the correct answer.**\nAmaravati in Andhra Pradesh holds historical significance..."
        },
        {
          "source": "Forum IAS",
          "markdown": "**Exp) Option a is the correct answer.**\nDharanikota is a town near Amaravati..."
        }
      ],
      "availableSources": ["Prisma IAS", "Forum IAS"],
      "selectedSource": "Prisma IAS"
    }
  ]
}
```

### Backward Compatible Format (Still Supported)
```json
{
  "id": "test-id",
  "title": "Test Title",
  "questions": [
    {
      "id": "q1",
      "questionText": "Question text...",
      "options": { "a": "...", "b": "...", "c": "...", "d": "..." },
      "correctAnswer": "A",
      "explanationMarkdown": "Single explanation text..."
    }
  ]
}
```

## Data Structure Design

### New Structure (Backward Compatible)
```javascript
{
  id: "question-id",
  questionText: "...",
  options: { "a": "...", "b": "...", "c": "...", "d": "..." },
  correctAnswer: "A",
  // Keep existing field for backward compatibility
  explanationMarkdown: "Default explanation text...",
  // New fields for multiple explanations
  explanations: [
    {
      source: "Prisma IAS",
      markdown: "Explanation from Prisma IAS..."
    },
    {
      source: "Forum IAS",
      markdown: "Explanation from Forum IAS..."
    }
  ],
  availableSources: ["Prisma IAS", "Forum IAS"],
  selectedSource: "Prisma IAS" // Currently selected source
}
```

## Implementation Approach

### Phase 1: Import Logic (Safe, Non-Breaking)
- Modify `normalizeImportedTest()` to detect `explanations` array
- If `explanations` array exists:
  - Store it in the question object
  - Set `availableSources` from explanation sources
  - Set `selectedSource` to first explanation source
  - Set `explanationMarkdown` to first explanation (for backward compatibility)
- If `explanations` array doesn't exist:
  - Keep existing behavior (use `explanationMarkdown` directly)

### Phase 2: Question Rendering
- Use existing `renderExplanationSourceSwitcher()` function
- Show explanation selector when `availableSources` has more than 1 source
- Default to showing `explanationMarkdown` for single-source questions
- When user switches source, update `selectedSource` and display corresponding explanation

### Phase 3: State Management
- Add state variable to track selected explanation source per question
- Use question ID as key in state object
- Example: `state.selectedExplanationSources = { "question-id": "Forama IS" }`

### Phase 4: Event Handlers
- Add click handlers for explanation source buttons
- Update state when user switches source
- Re-render question with new explanation

### Phase 5: Admin Tools
- Add ability to edit multiple explanations in Question Editor
- Add ability to add/remove explanation sources
- Show all explanations in Advanced Search results

## Backward Compatibility Strategy

### Import Compatibility
- Existing JSON files with `explanationMarkdown` will continue to work
- New JSON files with `explanations` array will be processed correctly
- No breaking changes to existing import logic

### Display Compatibility
- Questions with single explanation will show as before
- Questions with multiple explanations will show source selector
- If selector not clicked, defaults to first explanation

### Database Compatibility
- Supabase schema update will be additive (new columns, not modifying existing)
- Existing questions will have `explanations` array null or empty
- New questions will have populated `explanations` array

## UI Design

### Explanation Selector (Already Exists)
The `renderExplanationSourceSwitcher()` function already exists in `formatters.js`. It will be used to display:
- A dropdown or button group showing available sources
- Currently selected source highlighted
- Click handler to switch sources

### Example UI
```
┌─────────────────────────────────────────┐
│ Question text...                        │
│                                         │
│ A) Option A    B) Option B             │
│ C) Option C    D) Option D             │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ Explanation Source: [Forama IS ▼]  │ │
│ │ 2 sources available                 │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ Explanation from Forama IS...           │
└─────────────────────────────────────────┘
```

## Supabase Schema Changes

### New Columns (Additive Only)
```sql
ALTER TABLE questions ADD COLUMN explanations JSONB DEFAULT '[]'::jsonb;
ALTER TABLE questions ADD COLUMN available_sources TEXT[] DEFAULT '{}'::text[];
ALTER TABLE questions ADD COLUMN selected_source TEXT DEFAULT NULL;
```

### Migration Strategy
- New columns will default to empty/null for existing questions
- Existing questions will continue to use `explanation_markdown` column
- New questions can use both old and new formats

## Testing Plan

### Test Cases
1. Import JSON with single `explanationMarkdown` - should work as before
2. Import JSON with `explanations` array - should populate new fields
3. View question with single explanation - should show normally
4. View question with multiple explanations - should show selector
5. Switch between explanation sources - should update display
6. Search for questions with multiple explanations - should work
7. Edit question with multiple explanations - should allow editing

### Rollback Plan
- If issues arise, revert to using `explanationMarkdown` only
- New columns can be ignored in queries
- Import logic can fall back to old format

## Implementation Order (Safe, Incremental)

1. **Design Review** - Review this document with user
2. **Import Logic** - Add support for `explanations` array (safe, backward compatible)
3. **Test Import** - Test importing new format without breaking existing imports
4. **State Management** - Add state for selected sources
5. **UI Integration** - Integrate explanation selector with existing function
6. **Admin Tools** - Add explanation management to admin panel
7. **Full Testing** - Test all scenarios including backward compatibility

## Risk Mitigation

### Risk: Breaking Existing Imports
- **Mitigation**: Import logic will check for both formats, default to old format if new format not present
- **Rollback**: Can ignore new columns and use old format exclusively

### Risk: Display Issues
- **Mitigation**: UI will check if multiple sources exist before showing selector
- **Rollback**: Can disable selector and always show `explanationMarkdown`

### Risk: Database Issues
- **Mitigation**: New columns are additive, not modifying existing structure
- **Rollback**: Can drop new columns and revert to old schema

## Next Steps

1. Review this design document
2. Approve design before implementation
3. Implement Phase 1 (Import Logic) as a test
4. Verify backward compatibility with existing tests
5. Proceed to Phase 2 (Question Rendering) after Phase 1 is stable
