import csv
import json
import tempfile
import argparse
import re

from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4

from google.cloud import bigquery, storage

from preflight import main as run_preflight


CONFIG_DIR = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-id")
    args = parser.parse_args()

    if args.run_id and not re.fullmatch(
        r"\d{8}T\d{6}_[0-9a-f]{8}", args.run_id
    ):
        parser.error("Invalid candidate run ID.")

    run_preflight()

    manifest = json.loads(
        (CONFIG_DIR / "sources.json").read_text(encoding="utf-8-sig")
    )
    schemas = json.loads(
        (CONFIG_DIR / "schemas.json").read_text(encoding="utf-8-sig")
    )

    project = manifest["project_id"]
    candidate_dataset = manifest["candidate_dataset_id"]
    location = manifest["location"]

    # Prevent accidental loading into the existing raw dataset.
    if candidate_dataset != "olist_raw_candidate":
        raise ValueError("Destination must be olist_raw_candidate.")
    if candidate_dataset == manifest["dataset_id"]:
        raise ValueError("Candidate and raw datasets must differ.")

    bq = bigquery.Client(project=project)
    gcs = storage.Client(project=project)

    dataset = bq.get_dataset(f"{project}.{candidate_dataset}")
    if dataset.location.lower() != location.lower():
        raise ValueError("Candidate dataset location is incorrect.")

    run_id = args.run_id or (
        datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S")
        + "_"
        + uuid4().hex[:8]
    )
    print(f"CANDIDATE RUN: {run_id}", flush=True)

    bucket = gcs.bucket(manifest["bucket"])

    # Capture the source versions before loading any tables.
    sources = []
    for source in manifest["sources"]:
        blob = bucket.get_blob(manifest["prefix"] + source["file"])
        if blob is None or not blob.size:
            raise ValueError(f"Missing or empty source: {source['file']}")
        sources.append((source, blob))

    results = []

    with tempfile.TemporaryDirectory(prefix="olist-candidate-") as temp_dir:
        for source, blob in sources:
            table_name = source["table"]
            columns = schemas["tables"][table_name]
            local_file = Path(temp_dir) / f"{table_name}.csv"

            # Download the captured object version, not an unchecked latest copy.
            blob.download_to_filename(
                str(local_file),
                if_generation_match=int(blob.generation),
            )

            row_count = 0
            with local_file.open(
                "r", encoding="utf-8-sig", newline=""
            ) as handle:
                reader = csv.reader(handle, strict=True)

                if next(reader, None) != columns:
                    raise ValueError(f"{table_name}: CSV header mismatch.")

                for record_number, row in enumerate(reader, start=2):
                    if len(row) != len(columns):
                        raise ValueError(
                            f"{table_name}: record {record_number} has "
                            f"{len(row)} fields; expected {len(columns)}."
                        )
                    row_count += 1

            if row_count == 0:
                raise ValueError(f"{table_name}: source has no data rows.")

            destination = (
                f"{project}.{candidate_dataset}.{table_name}__{run_id}"
            )

            config = bigquery.LoadJobConfig(
                source_format=bigquery.SourceFormat.CSV,
                schema=[
                    bigquery.SchemaField(column, "STRING", mode="NULLABLE")
                    for column in columns
                ],
                autodetect=False,
                skip_leading_rows=1,
                encoding="UTF-8",
                allow_quoted_newlines=True,
                allow_jagged_rows=False,
                ignore_unknown_values=False,
                max_bad_records=0,
                write_disposition=bigquery.WriteDisposition.WRITE_EMPTY,
                labels={
                    "pipeline": "olist_ingestion",
                    "stage": "candidate",
                    "run_id": run_id.lower(),
                },
            )

            with local_file.open("rb") as handle:
                job = bq.load_table_from_file(
                    handle,
                    destination,
                    location=location,
                    job_config=config,
                    job_id=f"olist_candidate_{table_name}_{run_id}",
                )
                job.result()

            table = bq.get_table(destination)
            expected_schema = [
                (column, "STRING", "NULLABLE") for column in columns
            ]
            actual_schema = [
                (field.name, field.field_type, field.mode)
                for field in table.schema
            ]

            if actual_schema != expected_schema:
                raise ValueError(f"{table_name}: loaded schema mismatch.")

            if table.num_rows != row_count:
                raise ValueError(
                    f"{table_name}: expected {row_count} rows, "
                    f"loaded {table.num_rows}."
                )

            result = {
                "source_table": table_name,
                "candidate_table": destination,
                "source_generation": str(blob.generation),
                "source_rows": row_count,
                "loaded_rows": table.num_rows,
                "load_job_id": job.job_id,
            }
            results.append(result)
            print(json.dumps(result), flush=True)

    print(
        f"SUCCESS: {len(results)} candidate tables loaded "
        f"for run {run_id}. Raw tables unchanged.",
        flush=True,
    )


if __name__ == "__main__":
    main()