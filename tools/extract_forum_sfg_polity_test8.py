from forum_sfg_polity_common import build_payload, normalize_text, write_payload


def map_topic(_qno: int, source_topic: str, _question_text: str, _source: dict) -> str:
    topic = normalize_text(source_topic)
    if topic in {"System of Panchayats", "Panchayats", "Local Self Government", "Municipalities", "Munacipalities"}:
        return "Local Government"
    if topic in {
        "e-Governance",
        "e- Governance",
        "Governance",
        "Right to Information",
        "Non-Government Organisations",
        "Citizen Charter",
    }:
        return "Governance & Policies"
    if topic == "Administration of Scheduled and Tribal Areas":
        return "Miscellaneous"
    return "Miscellaneous"


def main() -> None:
    payload, out_path = build_payload(8, "Test 8 SOL Polity Level 1 SFG 2026.pdf", map_topic)
    write_payload(payload, out_path)
    print(out_path)


if __name__ == "__main__":
    main()
