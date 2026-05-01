from forum_sfg_polity_common import build_payload, normalize_text, write_payload


def map_topic(_qno: int, source_topic: str, _question_text: str, _source: dict) -> str:
    topic = normalize_text(source_topic)
    if topic in {"Parliament", "State Legislature", "Parliamentary Committees/Forums/Groups"}:
        return "Parliament"
    return "Miscellaneous"


def main() -> None:
    payload, out_path = build_payload(6, "Test 6 SOL Polity Level 1 SFG 2026.pdf", map_topic)
    write_payload(payload, out_path)
    print(out_path)


if __name__ == "__main__":
    main()
