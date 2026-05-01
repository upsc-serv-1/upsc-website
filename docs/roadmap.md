# UPSC Vault Test Practice Roadmap

## Namespace

- Firebase namespace: `upsc-vault-test-v1`
- Current production site remains isolated on `upsc-vault-v5`

## Phase 1

1. Scaffold the separate multi-file test practice app.
2. Wire email/password authentication.
3. Create the practice flow for provider selection, subject selection, timer choice, and explanation mode.
4. Import `Forum SFG Level 1 -> Polity -> Test 1`.
5. Save per-user question states and test attempts in Firestore.
6. Add analytics cards for confidence vs correctness, source-wise performance, revision backlog, and time usage.

## Import Rules

- Prefer the SOL PDF if it already contains full English questions and options.
- If the SOL PDF does not contain full question text, use the English QP PDF and the SOL PDF together.
- Use clarification PDF only when a matching clarification file exists for the same test.
- Preserve explanation formatting, especially bold text, during extraction.
- Map all question topics to the controlled syllabus labels supplied by the user.
- Store the original source topic text separately for traceability.
- Do not auto-merge near-duplicate questions. Admin review should approve any merge.
