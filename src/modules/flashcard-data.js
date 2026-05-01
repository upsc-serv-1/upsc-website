/**
 * Flashcard Data Module — Supabase CRUD + Real-time subscriptions
 * Bridges the SM-2 engine with Supabase persistence.
 */
import { assertSupabaseReady } from "../supabase-config.js";
import { createCardState, processReview, freezeCard, unfreezeCard, isCardDue } from "./sm2-engine.js";

const CARD_COLUMNS = "id,question_id,test_id,question_text,answer_text,correct_answer,subject,section_group,microtopic,provider,source,explanation_markdown,created_at,updated_at";
const STUDY_SESSION_COLUMNS = "id,user_id,date,cards_reviewed,cards_correct,updated_at";
const FOLDER_COLUMNS = "id,user_id,name,microtopic,created_at,updated_at";

// ─── In-memory cache ──────────────────────────────────────────────
let cardsCache = [];
let userCardsCache = new Map(); // cardId -> userCardState
let foldersCache = [];
let studySessionCache = new Map(); // date -> { cardsReviewed, cardsCorrect }
let cacheLoaded = false;
let realtimeChannel = null;

// ─── Local storage fallback keys ──────────────────────────────────
const CACHE_KEY = "flashcard_cache_v1";
const USER_CARDS_CACHE_KEY = "flashcard_user_cards_v1";

function saveCacheToLocal() {
    try {
        localStorage.setItem(CACHE_KEY, JSON.stringify(cardsCache.slice(0, 500)));
        localStorage.setItem(USER_CARDS_CACHE_KEY, JSON.stringify(
            Array.from(userCardsCache.entries()).slice(0, 500)
        ));
    } catch (e) {
        console.warn("Flashcard cache save failed:", e);
    }
}

function loadCacheFromLocal() {
    try {
        const raw = localStorage.getItem(CACHE_KEY);
        if (raw) cardsCache = JSON.parse(raw);
        const rawUC = localStorage.getItem(USER_CARDS_CACHE_KEY);
        if (rawUC) userCardsCache = new Map(JSON.parse(rawUC));
    } catch (e) {
        console.warn("Flashcard cache load failed:", e);
    }
}

// ─── Cards (static content) ───────────────────────────────────────

export async function loadCards(filters = {}) {
    const client = assertSupabaseReady();
    let query = client.from("cards").select(CARD_COLUMNS);

    if (filters.subject) query = query.eq("subject", filters.subject);
    if (filters.microtopic) query = query.eq("microtopic", filters.microtopic);
    if (filters.sectionGroup) query = query.eq("section_group", filters.sectionGroup);

    const { data, error } = await query;
    if (error) throw error;
    cardsCache = data || [];
    saveCacheToLocal();
    return cardsCache;
}

export async function loadCardsByMicrotopic(microtopic) {
    return loadCards({ microtopic });
}

export async function upsertCardsFromQuestions(questions, testId, testMeta = {}) {
    const client = assertSupabaseReady();
    const rows = questions.map(q => {
        const questionText = q.questionText || (Array.isArray(q.statementLines) ? q.statementLines.join("\n") : "") || "";
        return {
            question_id: q.id,
            test_id: testId,
            question_text: questionText,
            answer_text: q.answerText || q.options?.[q.correctAnswer] || q.correctAnswer || "",
            correct_answer: q.correctAnswer || null,
            subject: q.subject || testMeta.subject || null,
            section_group: q.sectionGroup || q.section_group || testMeta.sectionGroup || null,
            microtopic: q.microTopic || q.microtopic || null,
            provider: q.provider || testMeta.provider || null,
            source: q.source || {},
            explanation_markdown: q.explanationMarkdown || ""
        };
    });

    const attemptUpsert = async (batch, variant = "full") => {
        let payload = batch;
        if (variant === "no-source") {
            payload = batch.map(({ source, ...row }) => row);
        } else if (variant === "minimal") {
            payload = batch.map(({ source, provider, microtopic, section_group, explanation_markdown, subject, correct_answer, ...row }) => ({
                ...row,
                correct_answer: correct_answer ?? null,
                subject: subject ?? null
            }));
        }
        return client.from("cards").upsert(payload, {
            onConflict: "question_id,test_id",
            ignoreDuplicates: true
        }).select();
    };

    const results = [];
    for (let i = 0; i < rows.length; i += 50) {
        const batch = rows.slice(i, i + 50);
        let response = await attemptUpsert(batch, "full");
        if (response.error) {
            console.warn("Card upsert error (full payload):", response.error);
            response = await attemptUpsert(batch, "no-source");
        }
        if (response.error) {
            console.warn("Card upsert error (without source):", response.error);
            response = await attemptUpsert(batch, "minimal");
        }
        const { data, error } = response;
        if (error) {
            console.warn("Card upsert error (minimal payload):", error);
        }
        if (data) {
            results.push(...data);
            data.forEach((row) => {
                if (!row?.id) return;
                const existingIndex = cardsCache.findIndex((card) => card.id === row.id);
                if (existingIndex >= 0) {
                    cardsCache[existingIndex] = { ...cardsCache[existingIndex], ...row };
                } else {
                    cardsCache.push(row);
                }
            });
        }
    }
    saveCacheToLocal();
    return results;
}

function findCachedCardByQuestion(questionId, testId = null) {
    const normalizedQuestionId = questionId == null ? "" : String(questionId);
    const normalizedTestId = testId == null ? "" : String(testId);
    return cardsCache.find((card) => {
        const sameQuestion = String(card?.question_id ?? "") === normalizedQuestionId;
        if (!sameQuestion) return false;
        if (!normalizedTestId) return true;
        return String(card?.test_id ?? "") === normalizedTestId;
    }) || null;
}

// ─── User Cards (progress tracking) ──────────────────────────────

export async function loadUserCards(uid) {
    const client = assertSupabaseReady();
    const { data, error } = await client
        .from("user_cards")
        .select("*, cards(*)")
        .eq("user_id", uid);

    if (error) throw error;

    userCardsCache.clear();
    (data || []).forEach(row => {
        const cardState = {
            id: row.id,
            cardId: row.card_id,
            userId: row.user_id,
            status: row.status,
            repetitions: row.repetitions,
            interval: row.interval_days,
            easeFactor: row.ease_factor,
            nextReview: row.next_review,
            lastReviewed: row.last_reviewed,
            learningStatus: row.learning_status,
            againCount: row.again_count,
            userNote: row.user_note,
            createdAt: row.created_at,
            // Denormalized card content for quick access
            questionText: row.cards?.question_text || "",
            answerText: row.cards?.answer_text || "",
            correctAnswer: row.cards?.correct_answer || "",
            subject: row.cards?.subject || "",
            sectionGroup: row.cards?.section_group || "",
            microTopic: row.cards?.microtopic || "",
            provider: row.cards?.provider || "",
            source: row.cards?.source || {},
            explanationMarkdown: row.cards?.explanation_markdown || "",
            questionId: row.cards?.question_id || "",
            testId: row.cards?.test_id || ""
        };
        userCardsCache.set(row.card_id, cardState);
    });

    cacheLoaded = true;
    saveCacheToLocal();
    return Array.from(userCardsCache.values());
}

export async function ensureUserCardExists(uid, cardId) {
    const client = assertSupabaseReady();
    const existing = userCardsCache.get(cardId);
    if (existing) return existing;

    const newState = createCardState(cardId);
    const { data, error } = await client
        .from("user_cards")
        .insert({
            user_id: uid,
            card_id: cardId,
            status: newState.status,
            repetitions: newState.repetitions,
            interval_days: newState.interval,
            ease_factor: newState.easeFactor,
            next_review: newState.nextReview,
            learning_status: newState.learningStatus,
            again_count: newState.againCount,
            user_note: newState.userNote
        })
        .select()
        .single();

    if (error && error.code !== "23505" && error.status !== 409) throw error;

    if ((error?.code === "23505" || error?.status === 409) && !data) {
        const { data: existingRow, error: fetchError } = await client
            .from("user_cards")
            .select("*, cards(*)")
            .eq("user_id", uid)
            .eq("card_id", cardId)
            .maybeSingle();
        if (fetchError) throw fetchError;
        if (existingRow) {
            const cardState = {
                id: existingRow.id,
                cardId: existingRow.card_id,
                userId: existingRow.user_id,
                status: existingRow.status,
                repetitions: existingRow.repetitions,
                interval: existingRow.interval_days,
                easeFactor: existingRow.ease_factor,
                nextReview: existingRow.next_review,
                lastReviewed: existingRow.last_reviewed,
                learningStatus: existingRow.learning_status,
                againCount: existingRow.again_count,
                userNote: existingRow.user_note,
                createdAt: existingRow.created_at,
                questionText: existingRow.cards?.question_text || "",
                answerText: existingRow.cards?.answer_text || "",
                correctAnswer: existingRow.cards?.correct_answer || "",
                subject: existingRow.cards?.subject || "",
                sectionGroup: existingRow.cards?.section_group || "",
                microTopic: existingRow.cards?.microtopic || "",
                provider: existingRow.cards?.provider || "",
                source: existingRow.cards?.source || {},
                explanationMarkdown: existingRow.cards?.explanation_markdown || "",
                questionId: existingRow.cards?.question_id || "",
                testId: existingRow.cards?.test_id || ""
            };
            userCardsCache.set(cardId, cardState);
            saveCacheToLocal();
            return cardState;
        }
    }

    if (data) {
        const cardState = { ...newState, id: data.id, userId: uid, cardId };
        userCardsCache.set(cardId, cardState);
    }
    return userCardsCache.get(cardId);
}

export async function ensureUserCardForQuestion(uid, question, testId, testMeta = {}) {
    const questionId = question?.id ?? question?.questionId ?? question?.question_id ?? null;
    const resolvedTestId = testId ?? question?.testId ?? question?.test_id ?? null;
    if (questionId == null || resolvedTestId == null) {
        throw new Error("Question ID and test ID are required to create flashcard state.");
    }

    const existingByQuestion = Array.from(userCardsCache.values()).find((card) => {
        const sameQuestion = String(card?.questionId ?? card?.question_id ?? "") === String(questionId);
        const sameTest = String(card?.testId ?? card?.test_id ?? "") === String(resolvedTestId);
        return sameQuestion && sameTest;
    });
    if (existingByQuestion?.cardId) {
        return existingByQuestion;
    }

    let cardRow = findCachedCardByQuestion(questionId, resolvedTestId);
    if (!cardRow) {
        const ensuredRows = await upsertCardsFromQuestions([question], resolvedTestId, testMeta);
        cardRow = ensuredRows.find((row) => String(row?.question_id ?? "") === String(questionId))
            || findCachedCardByQuestion(questionId, resolvedTestId);
    }
    if (!cardRow?.id) {
        console.warn("Unable to create/find flashcard record", {
            questionId: String(questionId),
            testId: String(resolvedTestId),
            question,
            testMeta
        });
        throw new Error("Flashcard record could not be created for this question.");
    }

    const ensured = await ensureUserCardExists(uid, cardRow.id);
    if (ensured) {
        userCardsCache.set(cardRow.id, {
            ...ensured,
            questionId: ensured.questionId || String(questionId),
            testId: ensured.testId || String(resolvedTestId),
            questionText: ensured.questionText || question?.questionText || "",
            answerText: ensured.answerText || question?.answerText || question?.options?.[question?.correctAnswer] || "",
            correctAnswer: ensured.correctAnswer || question?.correctAnswer || "",
            subject: ensured.subject || question?.subject || testMeta?.subject || "",
            sectionGroup: ensured.sectionGroup || question?.sectionGroup || testMeta?.sectionGroup || "",
            microTopic: ensured.microTopic || question?.microTopic || "",
            provider: ensured.provider || question?.provider || testMeta?.provider || "",
            explanationMarkdown: ensured.explanationMarkdown || question?.explanationMarkdown || "",
            source: ensured.source || question?.source || {}
        });
        saveCacheToLocal();
    }
    return userCardsCache.get(cardRow.id) || ensured;
}

export async function reviewCard(uid, cardId, difficulty, customIntervals = null) {
    const client = assertSupabaseReady();
    const current = userCardsCache.get(cardId) || await ensureUserCardExists(uid, cardId);
    const updated = processReview(current, difficulty, customIntervals);

    const { error } = await client
        .from("user_cards")
        .update({
            repetitions: updated.repetitions,
            interval_days: updated.interval,
            ease_factor: updated.easeFactor,
            next_review: updated.nextReview,
            last_reviewed: updated.lastReviewed,
            learning_status: updated.learningStatus,
            again_count: updated.againCount,
            updated_at: new Date().toISOString()
        })
        .eq("user_id", uid)
        .eq("card_id", cardId);

    if (error) throw error;

    // Update cache immediately
    userCardsCache.set(cardId, { ...current, ...updated });
    saveCacheToLocal();

    // Update study session for today
    await incrementStudySession(uid, 1, difficulty !== "again" ? 1 : 0);

    return updated;
}

export async function freezeCardInDb(uid, cardId) {
    const client = assertSupabaseReady();
    const current = userCardsCache.get(cardId);
    if (!current) return;

    const updated = freezeCard(current);
    const { error } = await client
        .from("user_cards")
        .update({ status: "frozen", updated_at: new Date().toISOString() })
        .eq("user_id", uid)
        .eq("card_id", cardId);

    if (error) throw error;
    userCardsCache.set(cardId, { ...current, ...updated });
    saveCacheToLocal();
    return updated;
}

export async function unfreezeCardInDb(uid, cardId) {
    const client = assertSupabaseReady();
    const current = userCardsCache.get(cardId);
    if (!current) return;

    const updated = unfreezeCard(current);
    const { error } = await client
        .from("user_cards")
        .update({
            status: "active",
            repetitions: 0,
            interval_days: 0,
            ease_factor: 2.5,
            next_review: updated.nextReview,
            learning_status: "not_studied",
            updated_at: new Date().toISOString()
        })
        .eq("user_id", uid)
        .eq("card_id", cardId);

    if (error) throw error;
    userCardsCache.set(cardId, { ...current, ...updated });
    saveCacheToLocal();
    return updated;
}

export async function updateCardNote(uid, cardId, note) {
    const client = assertSupabaseReady();
    const current = userCardsCache.get(cardId);
    if (!current) return;

    const { error } = await client
        .from("user_cards")
        .update({ user_note: note, updated_at: new Date().toISOString() })
        .eq("user_id", uid)
        .eq("card_id", cardId);

    if (error) throw error;
    userCardsCache.set(cardId, { ...current, userNote: note });
    saveCacheToLocal();
}

export async function moveCardToFolders(uid, cardId, folderIds) {
    const client = assertSupabaseReady();
    // Remove existing mappings
    const { error: delError } = await client
        .from("card_folder_map")
        .delete()
        .in("folder_id", (await client.from("folders").select("id").eq("user_id", uid)).data?.map(f => f.id) || []);
    
    // Add new mappings
    const rows = folderIds.map(fid => ({ card_id: cardId, folder_id: fid }));
    if (rows.length) {
        const { error } = await client.from("card_folder_map").insert(rows);
        if (error) throw error;
    }
}

// ─── Study Sessions ──────────────────────────────────────────────

export async function incrementStudySession(uid, cardsReviewed, cardsCorrect) {
    const client = assertSupabaseReady();
    const today = new Date().toISOString().split("T")[0];

    const { data: existing } = await client
        .from("study_sessions")
        .select(STUDY_SESSION_COLUMNS)
        .eq("user_id", uid)
        .eq("date", today)
        .single();

    if (existing) {
        const { error } = await client
            .from("study_sessions")
            .update({
                cards_reviewed: existing.cards_reviewed + cardsReviewed,
                cards_correct: existing.cards_correct + cardsCorrect,
                updated_at: new Date().toISOString()
            })
            .eq("id", existing.id);
        if (error) throw error;
    } else {
        const { error } = await client
            .from("study_sessions")
            .insert({
                user_id: uid,
                date: today,
                cards_reviewed: cardsReviewed,
                cards_correct: cardsCorrect
            });
        if (error) throw error;
    }

    studySessionCache.set(today, {
        cardsReviewed: (studySessionCache.get(today)?.cardsReviewed || 0) + cardsReviewed,
        cardsCorrect: (studySessionCache.get(today)?.cardsCorrect || 0) + cardsCorrect
    });
}

export async function loadStudySessions(uid, days = 365) {
    const client = assertSupabaseReady();
    const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString().split("T")[0];
    const { data, error } = await client
        .from("study_sessions")
        .select(STUDY_SESSION_COLUMNS)
        .eq("user_id", uid)
        .gte("date", since)
        .order("date", { ascending: true });

    if (error) throw error;

    studySessionCache.clear();
    (data || []).forEach(s => {
        studySessionCache.set(s.date, {
            cardsReviewed: s.cards_reviewed,
            cardsCorrect: s.cards_correct
        });
    });
    return data || [];
}

// ─── Folders ──────────────────────────────────────────────────────

export async function loadFolders(uid) {
const client = assertSupabaseReady();
const { data, error } = await client
    .from("folders")
    .select(FOLDER_COLUMNS)
    .eq("user_id", uid)
    .order("name");
if (error) throw error;
foldersCache = data || [];
return foldersCache;
}

export async function createFolder(uid, name, microtopic = null) {
const client = assertSupabaseReady();
const { data, error } = await client
    .from("folders")
    .insert({ user_id: uid, name, microtopic })
    .select()
    .single();
if (error) throw error;
foldersCache.push(data);
return data;
}

// Delete card state
export async function deleteCardState(userId, questionId) {
const { error } = await supabase
    .from('flashcard_states')
    .delete()
    .eq('user_id', userId)
    .eq('question_id', questionId);
    
if (error) throw error;
}

// ─── Real-time subscriptions ──────────────────────────────────────

export function subscribeToUserCards(uid, onChange) {
    const client = assertSupabaseReady();

    if (realtimeChannel) {
        client.removeChannel(realtimeChannel);
    }

    realtimeChannel = client
        .channel(`user_cards:${uid}`)
        .on("postgres_changes",
            { event: "*", schema: "public", table: "user_cards", filter: `user_id=eq.${uid}` },
            (payload) => {
                if (payload.eventType === "UPDATE" && payload.new) {
                    const cardId = payload.new.card_id;
                    const existing = userCardsCache.get(cardId) || {};
                    userCardsCache.set(cardId, {
                        ...existing,
                        status: payload.new.status,
                        repetitions: payload.new.repetitions,
                        interval: payload.new.interval_days,
                        easeFactor: payload.new.ease_factor,
                        nextReview: payload.new.next_review,
                        lastReviewed: payload.new.last_reviewed,
                        learningStatus: payload.new.learning_status,
                        againCount: payload.new.again_count,
                        userNote: payload.new.user_note
                    });
                    saveCacheToLocal();
                }
                if (onChange) onChange(payload);
            }
        )
        .subscribe();

    return realtimeChannel;
}

export function unsubscribeFromUserCards() {
    if (realtimeChannel) {
        const client = assertSupabaseReady();
        client.removeChannel(realtimeChannel);
        realtimeChannel = null;
    }
}

// ─── Cache accessors ──────────────────────────────────────────────

export function getCachedUserCards() {
    return Array.from(userCardsCache.values());
}

export function getCachedUserCard(cardId) {
    return userCardsCache.get(cardId) || null;
}

export function getCachedCards() {
    return cardsCache;
}

export function getCachedFolders() {
    return foldersCache;
}

export function getCachedStudySessions() {
    return studySessionCache;
}

// Get card state for a question ID
export function getCardState(questionId) {
    const cards = getCachedUserCards();
    const id = questionId == null ? "" : String(questionId);
    return cards.find((card) => {
        const qid = card.questionId != null ? String(card.questionId) : (card.question_id != null ? String(card.question_id) : "");
        return qid === id;
    }) || null;
}

// Upsert card state
export async function upsertCardState(uid, cardState) {
    const client = assertSupabaseReady();
    const { error } = await client
        .from("user_cards")
        .upsert(cardState);
    
    if (error) throw error;
    
    // Update cache
    userCardsCache.set(cardState.question_id, cardState);
}

// Get cards by user
export async function getCardsByUser(uid) {
    return loadUserCards(uid);
}

export function isCacheLoaded() {
    return cacheLoaded;
}

export function clearCache() {
    cardsCache = [];
    userCardsCache.clear();
    foldersCache = [];
    studySessionCache.clear();
    cacheLoaded = false;
}

// ─── Initialization ──────────────────────────────────────────────

export async function initializeFlashcardData(uid) {
    loadCacheFromLocal();

    try {
        // Load all state-tracked cards first
        await loadUserCards(uid);
        await Promise.all([
            loadFolders(uid),
            loadStudySessions(uid)
        ]);

        // Auto-fetch missing question metadata for those cards if needed
        // This ensures they appear in the tree even if tests weren't manually visited
    } catch (e) {
        console.warn("Flashcard data sync failed:", e);
    }

    subscribeToUserCards(uid);
}
