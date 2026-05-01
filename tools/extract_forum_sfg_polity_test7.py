from forum_sfg_polity_common import build_payload, normalize_text, write_payload


QUESTION_TOPIC_OVERRIDES = {
    21: "Miscellaneous",
    36: "Non-Constitutional Bodies",
    37: "Constitutional Bodies",
    39: "Miscellaneous",
    49: "Miscellaneous",
    50: "Miscellaneous",
}


def map_topic(qno: int, source_topic: str, _question_text: str, _source: dict) -> str:
    if qno in QUESTION_TOPIC_OVERRIDES:
        return QUESTION_TOPIC_OVERRIDES[qno]

    topic = normalize_text(source_topic)
    if topic == "Central Executive":
        return "Union Executive"
    if topic in {"State Executive", "Central Executive/State Executive"}:
        return "Miscellaneous"
    if topic == "Central Executive/The Services and Public Service Commissions":
        return "Non-Constitutional Bodies"
    if topic == "The Services and Public Service Commissions":
        return "Constitutional Bodies"
    if topic in {
        "Rights and Liabilities of the Government",
        "All India Services",
        "Rights and Liabilities of the Government and Public Servants",
    }:
        return "Miscellaneous"
    return "Miscellaneous"


def main() -> None:
    payload, out_path = build_payload(7, "Test 7 SOL Polity Level 1 SFG 2026.pdf", map_topic)
    write_payload(payload, out_path)
    print(out_path)


if __name__ == "__main__":
    main()
