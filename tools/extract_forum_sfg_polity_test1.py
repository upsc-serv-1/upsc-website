from forum_sfg_polity_common import build_payload, write_payload


def topic_mapper(qno: int, original_topic_text: str, question_text: str, source: dict) -> str:
    return original_topic_text or "Miscellaneous"


def main() -> None:
    payload, out_path = build_payload(1, "Test 1 SOL Polity Level 1 SFG 2026.pdf", topic_mapper)
    write_payload(payload, out_path)
    print(out_path)


if __name__ == "__main__":
    main()
