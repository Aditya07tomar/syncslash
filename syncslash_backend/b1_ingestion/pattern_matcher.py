from backend.db.connection import run_query

def run_pipeline(user_id: int) -> dict:

    result = run_query(
        "SELECT * FROM run_classification_pipeline(%s)",
        params=(user_id,)
    )
    pass1 = result[0]['pass1_updated']
    pass2 = result[0]['pass2_updated']
    print(f"[pipeline] Pass 1 (pattern match): {pass1} rows classified")
    print(f"[pipeline] Pass 2 (recurrence):    {pass2} rows classified")

    promoted = run_query(
        "SELECT upsert_detected_subscriptions(%s) AS count",
        params=(user_id,)
    )
    sub_count = promoted[0]['count']
    print(f"[pipeline] Subscriptions upserted: {sub_count}")

    return {
        "pass1_pattern_matches": pass1,
        "pass2_recurrence_detected": pass2,
        "subscriptions_updated": sub_count
    }