from forum_sfg_polity_common import build_payload, normalize_text, write_payload


QUESTION_TOPIC_OVERRIDES = {
    12: "Historical Background",
    13: "Historical Background",
    15: "Preamble",
    17: "Miscellaneous",
    35: "Miscellaneous",
    38: "Constitutional Bodies",
}


def map_topic(qno: int, source_topic: str, _question_text: str, _source: dict) -> str:
    if qno in QUESTION_TOPIC_OVERRIDES:
        return QUESTION_TOPIC_OVERRIDES[qno]

    topic = normalize_text(source_topic)
    if topic == "Executive":
        return "Union Executive"
    if topic == "Constitution of India":
        return "Salient Features"
    if topic == "Making of the Constitution":
        return "Making of Constitution"
    if topic == "Local Self Government":
        return "Local Government"
    if topic == "Judiciary":
        return "Judiciary"
    if topic == "Preamble":
        return "Preamble"
    if topic == "Administration of Scheduled and Tribal Areas":
        return "Miscellaneous"
    if topic == "Post Independent India":
        return "Miscellaneous"
    if topic == "Fundamental Rights":
        return "Fundamental Rights"
    if topic == "Awards and Honours":
        return "Miscellaneous"
    if topic == "Directive Principles of State Policy":
        return "DPSP"
    if topic == "Emergency":
        return "Emergency Provisions"
    if topic == "Miscellaneous":
        return "Miscellaneous"
    if topic == "Legislature":
        return "Parliament"
    if topic == "Constitutional and Non Constitutional Bodies":
        return "Miscellaneous"
    if topic == "Fundamental Duties":
        return "Fundamental Duties"
    return "Miscellaneous"


def main() -> None:
    payload, out_path = build_payload(9, "Test 9 SOL Revision (Polity) Level 1 SFG 2026.pdf", map_topic)
    write_payload(payload, out_path)
    print(out_path)


if __name__ == "__main__":
    main()
