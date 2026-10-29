import argparse
import hashlib
import json
import sys
from datetime import datetime, timezone

from google.api_core.exceptions import Conflict, NotFound
from google.cloud import bigquery


PROJECT = "olist-analytics-508208"
LOCATION = "asia-southeast1"
TABLE = f"{PROJECT}.olist_ops.pipeline_events"


def write_event(payload):
    required = (
        "dag_id",
        "airflow_run_id",
        "task_id",
        "try_number",
        "event_type",
    )
    for field in required:
        if field not in payload:
            raise ValueError(f"Missing event field: {field}")

    if payload["event_type"] not in {
        "TASK_STARTED",
        "TASK_SUCCEEDED",
        "TASK_FAILED",
        "TEST",
    }:
        raise ValueError("Unsupported event type.")

    if (
        type(payload["try_number"]) is not int
        or payload["try_number"] < 1
    ):
        raise ValueError("try_number must be a positive integer.")

    for field in ("dag_id", "airflow_run_id", "task_id"):
        if not isinstance(payload[field], str) or not payload[field]:
            raise ValueError(f"{field} must be a nonempty string.")

    identity = [payload[field] for field in required]
    event_id = hashlib.sha256(
        json.dumps(identity, separators=(",", ":")).encode("utf-8")
    ).hexdigest()

    row = {
        "event_id": event_id,
        "dag_id": payload["dag_id"],
        "airflow_run_id": payload["airflow_run_id"],
        "candidate_run_id": payload.get("candidate_run_id"),
        "task_id": payload["task_id"],
        "try_number": payload["try_number"],
        "event_type": payload["event_type"],
        "source_snapshot": payload.get("source_snapshot"),
        "details_json": json.dumps(
            payload.get("details", {}),
            sort_keys=True,
            separators=(",", ":"),
        ),
    }

    # Exclude submission time so a repeated event has the same fingerprint.
    payload_hash = hashlib.sha256(
        json.dumps(
            row, sort_keys=True, separators=(",", ":")
        ).encode("utf-8")
    ).hexdigest()[:63]

    row["event_time"] = datetime.now(timezone.utc).isoformat()

    client = bigquery.Client(project=PROJECT)
    table = client.get_table(TABLE)
    job_id = f"olist_audit_{event_id}"

    try:
        job = client.get_job(job_id, location=LOCATION)
        reused = True
    except NotFound:
        config = bigquery.LoadJobConfig(
            schema=table.schema,
            autodetect=False,
            create_disposition="CREATE_NEVER",
            write_disposition="WRITE_APPEND",
            labels={
                "pipeline": "olist_ingestion",
                "stage": "audit",
                "payload_hash": payload_hash,
            },
        )

        try:
            job = client.load_table_from_json(
                [row],
                TABLE,
                location=LOCATION,
                job_config=config,
                job_id=job_id,
            )
            reused = False
        except Conflict:
            job = client.get_job(job_id, location=LOCATION)
            reused = True

    if not isinstance(job, bigquery.LoadJob):
        raise RuntimeError("Audit job ID belongs to another job type.")

    if job.destination != bigquery.TableReference.from_string(TABLE):
        raise RuntimeError("Audit job destination mismatch.")

    if (job.labels or {}).get("payload_hash") != payload_hash:
        raise RuntimeError("Existing event has conflicting content.")

    if job.write_disposition != "WRITE_APPEND":
        raise RuntimeError("Unexpected audit write disposition.")

    job.result()

    if job.output_rows != 1:
        raise RuntimeError("Expected exactly one audit event.")

    print(
        f"AUDIT {'REUSED' if reused else 'WRITTEN'}: "
        f"{payload['event_type']} event_id={event_id}",
        flush=True,
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--test", action="store_true")
    args = parser.parse_args()

    if args.test:
        payload = {
            "dag_id": "olist_audit_test",
            "airflow_run_id": "manual_audit_writer_check_v1",
            "task_id": "event_writer",
            "try_number": 1,
            "event_type": "TEST",
            "details": {"purpose": "Verify audit event writing"},
        }
    else:
        payload = json.load(sys.stdin)
        if not isinstance(payload, dict):
            raise ValueError("Expected one JSON event object.")

    write_event(payload)


if __name__ == "__main__":
    main()