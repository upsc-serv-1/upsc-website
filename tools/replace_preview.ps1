$file = "c:\Users\Dr. Yogesh\Pictures\g1v12\src\app.js"
$lines = [System.IO.File]::ReadAllLines($file)

# Find start line (0-indexed)
$startLine = -1
$endLine = -1
for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match 'Opens a new browser tab with full duplicate-group comparison') {
        $startLine = $i
        break
    }
}

if ($startLine -eq -1) {
    Write-Error "Could not find start of openDuplicateGroupsPreviewTab"
    exit 1
}

# Find end of function by looking for "function renderPracticeMicrotopicPickerModal"
for ($i = $startLine + 1; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match 'function renderPracticeMicrotopicPickerModal') {
        $endLine = $i - 1 # the blank line before
        break
    }
}

if ($endLine -eq -1) {
    Write-Error "Could not find end of openDuplicateGroupsPreviewTab"
    exit 1
}

Write-Host "Replacing lines $startLine to $endLine (0-indexed)"

$newFunction = @'
/** Opens a new browser tab with full duplicate-group comparison and interactive merge. */
function openDuplicateGroupsPreviewTab(groups) {
    const list = Array.isArray(groups) ? groups.filter(Boolean) : [];
    if (!list.length) {
        setAdminNotice("Nothing to preview.");
        return;
    }
    const esc = (s) => escapeHtml(s == null ? "" : String(s));

    const formatOpts = (q) => {
        const opts = q?.options;
        if (Array.isArray(opts) && opts.length) {
            return opts.map((text, i) => {
                const letter = String.fromCharCode(97 + i);
                return `<li style="margin-bottom:6px;"><strong>${letter})</strong> ${esc(String(text || ""))}</li>`;
            }).join("");
        }
        const pairs = Object.entries(opts || {}).sort(([a], [b]) => a.localeCompare(b));
        if (!pairs.length) return "<li style='color:#94a3b8;'>No options</li>";
        return pairs.map(([key, value]) => `<li style="margin-bottom:6px;"><strong>${esc(key)})</strong> ${esc(String(value || ""))}</li>`).join("");
    };

    const blocks = [];
    list.forEach((group, gi) => {
        const questions = group.questions || [];
        const providers = group.providers || [];
        const bannerBg = group.allSameAnswer ? "#dcfce7" : "#fee2e2";
        const bannerFg = group.allSameAnswer ? "#166534" : "#991b1b";
        const providerBadges = providers.map((p) => `<strong>${esc(p)}</strong>`).join(" &middot; ");
        const answerLine = questions.map((q) => `${esc(q.provider)}: ${esc(q.correctAnswer || "N/A")}`).join(" | ");

        const explanationRadios = questions
            .filter((q) => q.explanationMarkdown || q.explanation)
            .map((q, qi) => {
                const charLen = (q.explanationMarkdown || q.explanation || "").length;
                return `<label style="display:flex;align-items:center;gap:6px;cursor:pointer;padding:8px 14px;background:white;border:2px solid #e2e8f0;border-radius:8px;">`
                    + `<input type="radio" name="primary_explanation_${gi}" value="${esc(q.provider)}" class="primary-explanation-radio" data-group="${gi}" ${qi === 0 ? "checked" : ""}>`
                    + `<span style="font-weight:600;">${esc(q.provider)}</span>`
                    + `<span style="color:#64748b;font-size:0.8rem;">(${charLen} chars)</span></label>`;
            }).join("");

        const questionCards = questions.map((q, qi) => {
            return `<article data-question-id="${esc(q.id)}" data-group="${gi}" style="border:2px solid #e2e8f0;border-radius:12px;overflow:hidden;background:#fff;">`
                + `<div style="padding:14px 16px;background:#f8fafc;border-bottom:1px solid #e2e8f0;display:flex;align-items:center;gap:12px;">`
                + `<input type="checkbox" class="question-checkbox" data-group="${gi}" data-index="${qi}" data-id="${esc(q.id)}" checked style="width:18px;height:18px;cursor:pointer;">`
                + `<div style="flex:1;">`
                + `<strong style="font-size:1.05rem;color:#0f172a;">${esc(q.provider)}</strong>`
                + `<span style="color:#64748b;font-size:0.85rem;margin-left:8px;">Test: ${esc(q.testTitle || "Unknown")} | Q#${esc(q.questionNumber != null ? String(q.questionNumber) : "-")} | Year: ${esc(q.year || "N/A")} | ${esc(q.subject || "")}</span>`
                + `</div>`
                + `<span style="padding:3px 10px;border-radius:6px;font-size:0.8rem;font-weight:600;background:#dbeafe;color:#1e40af;">Ans: ${esc(q.correctAnswer || "N/A")}</span>`
                + `</div>`
                + `<div style="padding:16px;">`
                + `<h4 style="margin:0 0 8px;font-size:0.95rem;color:#334155;">Question Text</h4>`
                + `<div style="white-space:pre-wrap;line-height:1.55;padding:12px;background:#f8fafc;border-radius:8px;font-size:0.95rem;">${esc(q.questionText || "")}</div>`
                + `<h4 style="margin:16px 0 8px;font-size:0.95rem;color:#334155;">Options</h4>`
                + `<ol style="margin:0;padding-left:20px;">${formatOpts(q)}</ol>`
                + `<h4 style="margin:16px 0 8px;font-size:0.95rem;color:#334155;">Explanation</h4>`
                + `<div style="white-space:pre-wrap;line-height:1.5;padding:12px;background:#eff6ff;border-radius:8px;border-left:3px solid #3b82f6;font-size:0.93rem;">${esc(q.explanationMarkdown || q.explanation || "- No explanation -")}</div>`
                + `</div></article>`;
        }).join("");

        blocks.push(`
            <section class="dup-group" data-group-index="${gi}" style="margin-bottom:40px;padding-bottom:32px;border-bottom:2px solid #e2e8f0;">
                <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:16px;">
                    <h2 style="margin:0;font-size:1.15rem;">Group ${gi + 1} of ${list.length}</h2>
                    <label style="display:flex;align-items:center;gap:8px;cursor:pointer;padding:8px 16px;background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;">
                        <input type="checkbox" class="group-select-all" data-group="${gi}" checked>
                        <span style="font-weight:600;font-size:0.9rem;">Select all</span>
                    </label>
                </div>
                <p style="margin:0 0 8px;color:#64748b;font-size:0.9rem;">Providers: ${providerBadges}</p>
                <div style="padding:12px 16px;border-radius:8px;margin-bottom:20px;background:${bannerBg};color:${bannerFg};">
                    <strong>${group.allSameAnswer ? "Same correct answer" : "Different correct answers"}</strong><br>
                    <span style="font-size:0.9rem;">${answerLine}</span>
                </div>
                <div style="margin-bottom:16px;padding:12px 16px;background:#f0f9ff;border:1px solid #bae6fd;border-radius:10px;">
                    <strong style="display:block;margin-bottom:8px;font-size:0.95rem;">Choose Primary Explanation Source:</strong>
                    <div style="display:flex;flex-wrap:wrap;gap:10px;">${explanationRadios}</div>
                </div>
                <div style="display:flex;flex-direction:column;gap:20px;">${questionCards}</div>
            </section>
        `);
    });

    const totalCards = list.reduce((n, g) => n + (g.questions || []).length, 0);
    const htmlParts = [
        `<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">`,
        `<title>Duplicate Preview and Merge (${list.length} groups)</title>`,
        `<style>`,
        `*{box-sizing:border-box}`,
        `body{font-family:system-ui,-apple-system,sans-serif;margin:0;padding:20px 20px 100px;background:#f1f5f9;color:#0f172a;max-width:1200px;margin-left:auto;margin-right:auto}`,
        `h1{font-size:1.35rem;margin-top:0}`,
        `.merge-bar{position:fixed;bottom:0;left:0;right:0;background:white;border-top:2px solid #3b82f6;padding:16px 24px;display:flex;justify-content:space-between;align-items:center;box-shadow:0 -4px 20px rgba(0,0,0,0.1);z-index:100}`,
        `.merge-bar button{padding:12px 32px;background:#3b82f6;color:white;border:none;border-radius:10px;font-size:1rem;font-weight:700;cursor:pointer}`,
        `.merge-bar button:hover{background:#2563eb}`,
        `#mergeStatus{display:none;margin-bottom:16px;padding:12px 20px;background:#dcfce7;color:#166534;border-radius:8px;font-weight:600;text-align:center}`,
        `</style></head><body>`,
        `<h1>Duplicate Detector - Full Preview and Merge</h1>`,
        `<p style="color:#64748b;margin-bottom:24px;">${totalCards} question(s) in ${list.length} group(s). Select questions to merge and choose the primary explanation source.</p>`,
        `<div id="mergeStatus"></div>`,
        blocks.join(""),
        `<div class="merge-bar">`,
        `<div><strong>Merge selected into UPSC Official canonical records</strong><br><span style="color:#64748b;font-size:0.85rem;">All explanations preserved. Primary explanation determines default display.</span></div>`,
        `<button id="mergeBtn">Merge Selected Groups</button>`,
        `</div>`,
        `<script>`,
        `document.addEventListener('DOMContentLoaded',function(){`,
        `document.querySelectorAll('.group-select-all').forEach(function(cb){cb.addEventListener('change',function(){var g=this.dataset.group;document.querySelectorAll('.question-checkbox[data-group="'+g+'"]').forEach(function(qcb){qcb.checked=cb.checked});})});`,
        `document.getElementById('mergeBtn').addEventListener('click',function(){`,
        `var mergeData={groups:[]};`,
        `document.querySelectorAll('.dup-group').forEach(function(section){`,
        `var gIdx=section.dataset.groupIndex;var selectedIds=[];`,
        `section.querySelectorAll('.question-checkbox:checked').forEach(function(cb){selectedIds.push(cb.dataset.id)});`,
        `var primaryRadio=section.querySelector('.primary-explanation-radio:checked');`,
        `var primaryProvider=primaryRadio?primaryRadio.value:'';`,
        `if(selectedIds.length>=2){mergeData.groups.push({groupIndex:parseInt(gIdx),selectedIds:selectedIds,primaryProvider:primaryProvider})}`,
        `});`,
        `if(!mergeData.groups.length){alert('Select at least 2 questions in a group to merge.');return}`,
        `if(window.opener){window.opener.postMessage({type:'UPSC_VAULT_MERGE_REQUEST',payload:mergeData},'*');`,
        `document.getElementById('mergeStatus').textContent='Merge request sent to main window. You can close this tab.';`,
        `document.getElementById('mergeStatus').style.display='block'`,
        `}else{alert('Cannot communicate with main window. Please use the merge function in the admin panel.')}`,
        `});`,
        `});`,
        `<\/script>`,
        `</body></html>`
    ];
    const html = htmlParts.join("\n");
    const blob = new Blob([html], { type: "text/html;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const win = window.open(url, "_blank");
    if (!win) {
        setAdminNotice("Popup blocked. Allow popups for this site to open the preview tab.");
        URL.revokeObjectURL(url);
        return;
    }
    // Listen for merge requests from the preview tab
    const mergeHandler = async (event) => {
        if (!event.data || event.data.type !== "UPSC_VAULT_MERGE_REQUEST") return;
        window.removeEventListener("message", mergeHandler);
        const payload = event.data.payload;
        if (!payload || !Array.isArray(payload.groups) || !payload.groups.length) return;
        state.adminProcessing = true;
        state.adminNotice = "Processing merge from preview tab...";
        renderApp();
        try {
            const affectedTestIds = new Set();
            for (const mergeGroup of payload.groups) {
                const groupIdx = mergeGroup.groupIndex;
                const group = list[groupIdx];
                if (!group) continue;
                const selectedIds = new Set(mergeGroup.selectedIds || []);
                const filteredGroup = {
                    ...group,
                    questions: group.questions.filter((q) => selectedIds.has(q.id))
                };
                if (filteredGroup.questions.length < 2) continue;
                await mergeDuplicateGroup(filteredGroup, "purge", "combined", mergeGroup.primaryProvider || null);
                filteredGroup.questions.forEach((q) => affectedTestIds.add(q.testId));
            }
            const idsArr = Array.from(affectedTestIds);
            for (const tid of idsArr) {
                const test = sampleTests.find((t) => t.id === tid);
                if (test) await saveFullTest(test);
            }
            const pyqTests = sampleTests.filter((t) => t.provider === "PYQ");
            for (const t of pyqTests) await saveFullTest(t);
            try { localStorage.removeItem("upscVault_allQuestions"); } catch {}
            try { await removeQuestionsFromCache([...idsArr, ...pyqTests.map((t) => t.id)]); } catch {}
            practiceSearchCacheKey = null;
            practiceSearchCacheResults = [];
            practiceSearchDataVersion++;
            scheduleMiniSearchRebuild();
            state.adminNotice = `Successfully merged ${payload.groups.length} group(s) from preview tab!`;
            state.canonicalMergeSelectedGroups = [];
            state.canonicalMergeReady = false;
        } catch (err) {
            console.error("Preview tab merge failed:", err);
            state.adminNotice = `Merge failed: ${err.message || "Unknown error"}`;
        } finally {
            state.adminProcessing = false;
            renderApp();
            setTimeout(() => { if (!state.adminProcessing) { state.adminNotice = ""; renderApp(); } }, 5000);
        }
    };
    window.addEventListener("message", mergeHandler);
    setTimeout(() => {
        try { URL.revokeObjectURL(url); } catch {}
    }, 120000);
}

'@

$before = $lines[0..($startLine - 1)]
$after = $lines[($endLine + 1)..($lines.Length - 1)]
$newLines = $before + ($newFunction -split "`n") + $after

[System.IO.File]::WriteAllLines($file, $newLines)
Write-Host "Successfully replaced openDuplicateGroupsPreviewTab function (lines $startLine-$endLine)"
