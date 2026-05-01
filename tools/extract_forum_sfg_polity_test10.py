from forum_sfg_polity_common import build_payload, normalize_text, write_payload


QUESTION_TOPIC_OVERRIDES = {
    4: "Parliament",
    8: "Miscellaneous",
    11: "Miscellaneous",
    25: "Miscellaneous",
    34: "Constitutional Bodies",
    44: "Miscellaneous",
    48: "Parliament",
}


def map_topic(qno: int, source_topic: str, _question_text: str, _source: dict) -> str:
    if qno in QUESTION_TOPIC_OVERRIDES:
        return QUESTION_TOPIC_OVERRIDES[qno]

    topic = normalize_text(source_topic)
    if topic == "Constitutional Amendments":
        return "Salient Features"
    if topic == "Elections":
        return "Miscellaneous"
    if topic in {
        "Scheduled Castes and Scheduled Tribes",
        "Other Constitutional Dimensions",
        "Co-Operative Societies",
        "Union Territories",
        "Language",
        "Minorities",
        "",
    }:
        return "Miscellaneous"
    if topic == "Anti-Defection":
        return "Parliament"
    return "Miscellaneous"


def main() -> None:
    payload, out_path = build_payload(10, "Test 10 SOL Polity Level 1 SFG 2026.pdf", map_topic)
    write_payload(payload, out_path)
    print(out_path)


if __name__ == "__main__":
    main()
