$file = "c:\Users\Dr. Yogesh\Pictures\g1v12\src\app.js"
$lines = [System.IO.File]::ReadAllLines($file)

# Find start line of renderSaveToNotePanel (0-indexed)
$startLine = -1
$endLine = -1
for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match '^function renderSaveToNotePanel\b') {
        $startLine = $i
        break
    }
}

if ($startLine -eq -1) {
    Write-Error "Could not find start of renderSaveToNotePanel"
    exit 1
}

# Find end of function by looking for "function renderAccessGate"
for ($i = $startLine + 1; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match '^function renderAccessGate\b') {
        $endLine = $i - 1 # usually there is a blank line, but let's be safe
        # Find the closing brace line before renderAccessGate
        while ($lines[$endLine].Trim() -ne "}" -and $endLine -gt $startLine) {
            $endLine--
        }
        break
    }
}

if ($endLine -eq -1) {
    Write-Error "Could not find end of renderSaveToNotePanel"
    exit 1
}

Write-Host "Replacing lines $startLine to $endLine (0-indexed)"

$newFunction = @'
function renderSaveToNotePanel() {
    if (!state.saveToNotePanelOpen || !isLoggedIn()) return "";
    
    const subjects = getUniqueNoteSubjects().filter((s) => s !== "All");
    const modalSubject = String(state.saveNoteModalSubject || "").trim();
    const notesMatchingSubject = modalSubject ? state.userNotes.filter((note) => note.subject === modalSubject) : [];
    
    const selectedNoteId = state.saveHighlightPendingNoteId;
    const selectedNote = notesMatchingSubject.find((n) => String(n.id) === String(selectedNoteId)) || null;

    const previewText = String(state.selectedText || "");
    
    const sourceInfo = state.textSelectionSource || {};
    let currentMicrotopic = "";
    if (sourceInfo.questionId) {
        const tests = window.sampleTests || []; // ensure we read from correct test scope although handled inside
        let q = null;
        for (let t of tests) {
             const found = (t.questions || []).find(qn => String(qn.id) === String(sourceInfo.questionId));
             if (found) { q = found; break; }
        }
        if (!q && typeof currentStudyQuestions === "function") {
             q = currentStudyQuestions().find(qn => String(qn.id) === String(sourceInfo.questionId));
        }
        if (q) currentMicrotopic = q.microTopic || "";
    }

    const sectionOptions = [
        { value: "__auto__", label: "Auto (use question topic as section)" }
    ];
    if (currentMicrotopic) {
        sectionOptions.push({ value: currentMicrotopic, label: `Use current microtopic (${currentMicrotopic})`});
    }
    sectionOptions.push({ value: "__top__", label: "Top of notebook (no subheading)" });

    if (selectedNote) {
        (selectedNote.items || []).forEach((item) => {
            if (item?.type === "microTopicHeading") {
                const v = String(item.key || item.text || "").trim();
                const lab = String(item.text || "").trim() || "Section";
                if (v && !sectionOptions.some((o) => o.value === v)) {
                    sectionOptions.push({ value: v, label: lab });
                }
            }
        });
    }

    return `
        <div class="modal-backdrop save-note-backdrop" id="saveNoteBackdrop">
            <section class="confirm-modal save-note-modal" role="dialog" aria-modal="true" aria-labelledby="saveNoteTitle">
                <div class="section-head compact-section-head">
                    <div>
                        <p class="eyebrow">Save Highlight</p>
                        <h3 id="saveNoteTitle">Add to Notebook</h3>
                        <p class="muted">Review your selected text and choose where to save it.</p>
                    </div>
                    <button class="ghost-btn small" type="button" id="closeSaveNoteBtn">✕</button>
                </div>
                <div class="save-note-content" style="padding-top: 0;">
                    <div class="highlight-preview" style="margin-bottom: 20px;">
                        <label class="small-label" style="display:block; margin-bottom: 8px;">Selected Text (Editable)</label>
                        <textarea id="saveNoteHighlightText" rows="4" style="width: 100%; padding: 12px; border: 1px solid var(--line); border-radius: 8px; background: var(--surface); resize: vertical; line-height: 1.5; font-family: inherit;">${escapeHtml(previewText)}</textarea>
                    </div>

                    <div class="note-selection" style="display: flex; flex-direction: column; gap: 16px;">
                        <div>
                            <label class="small-label" style="display:flex; justify-content:space-between; margin-bottom: 6px;">
                                <span>1. Select Subject</span>
                            </label>
                            <select id="saveNoteSubjectSelect" class="notes-select" style="width:100%; padding: 10px; border-radius: 8px; border: 1px solid var(--line);">
                                <option value="">Choose a subject...</option>
                                ${subjects.map((subject) => `
                                    <option value="${escapeHtml(subject)}" ${state.saveNoteModalSubject === subject ? "selected" : ""}>${escapeHtml(subject)}</option>
                                `).join("")}
                            </select>
                        </div>

                        ${modalSubject ? `
                            <div>
                                <label class="small-label" style="margin-bottom: 6px; display:block;">2. Select Notebook</label>
                                <select id="saveNoteNotebookSelect" class="notes-select" style="width:100%; padding: 10px; border-radius: 8px; border: 1px solid var(--line);">
                                    <option value="">Choose a notebook...</option>
                                    ${notesMatchingSubject.map((n) => `
                                        <option value="${String(n.id)}" ${String(selectedNoteId) === String(n.id) ? "selected" : ""}>${escapeHtml(n.title)}</option>
                                    `).join("")}
                                </select>
                                <div style="margin-top: 8px;">
                                   <input type="text" id="saveNoteNewTitle" placeholder="Or type a title to create a new notebook" style="width: 100%; padding: 8px 10px; border: 1px solid var(--line); border-radius: 8px; font-size: 0.9rem;">
                                </div>
                            </div>
                        ` : ''}

                        ${selectedNoteId ? `
                            <div>
                                <label class="small-label" style="margin-bottom: 6px; display:block;">3. Select Section (Heading)</label>
                                <select id="saveHighlightHeadingSelect" class="notes-select" style="width:100%; padding: 10px; border-radius: 8px; border: 1px solid var(--line);">
                                    ${sectionOptions.map((o) => `<option value="${escapeHtml(o.value)}">${escapeHtml(o.label)}</option>`).join("")}
                                </select>
                                <div style="margin-top: 8px;">
                                    <input type="text" id="saveHighlightNewSectionTitle" placeholder="Or type to create a new section heading" style="width: 100%; padding: 8px 10px; border: 1px solid var(--line); border-radius: 8px; font-size: 0.9rem;">
                                </div>
                            </div>
                            
                            <div class="stacked-chips" style="margin-top: 24px; display: flex; justify-content: flex-end;">
                                <button class="primary-btn" type="button" id="confirmSaveHighlightCombinedBtn">Add Note</button>
                            </div>
                        ` : (modalSubject ? `
                            <div class="stacked-chips" style="margin-top: 16px;">
                                <button class="primary-btn small" type="button" id="createNoteAndSaveHighlightBtn">Create Notebook & Add Note</button>
                            </div>
                        ` : "")}
                    </div>
                </div>
            </section>
        </div>
    `;
}
'@

$before = $lines[0..($startLine - 1)]
$after = $lines[($endLine + 1)..($lines.Length - 1)]
$newLines = $before + ($newFunction -split "`n") + $after

[System.IO.File]::WriteAllLines($file, $newLines)
Write-Host "Successfully replaced renderSaveToNotePanel function (lines $startLine-$endLine)"
