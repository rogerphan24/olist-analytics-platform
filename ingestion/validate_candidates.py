import argparse
import json
import re
from pathlib import Path

from google.cloud import bigquery


CONFIG_DIR = Path(__file__).resolve().parent

TABLES = (
    "customers",
    "geolocation",
    "order_items",
    "order_payments",
    "order_reviews",
    "orders",
    "products",
    "sellers",
    "product_category_translation",
)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-id", required=True)
    args = parser.parse_args()

    if not re.fullmatch(r"\d{8}T\d{6}_[0-9a-f]{8}", args.run_id):
        parser.error("Invalid candidate run ID.")

    manifest = json.loads(
        (CONFIG_DIR / "sources.json").read_text(encoding="utf-8-sig")
    )
    schemas = json.loads(
        (CONFIG_DIR / "schemas.json").read_text(encoding="utf-8-sig")
    )

    project = manifest["project_id"]
    raw_dataset = manifest["dataset_id"]
    candidate_dataset = manifest["candidate_dataset_id"]
    location = manifest["location"]

    # Restrict this validator to our intended datasets.
    if (
        project != "olist-analytics-508208"
        or raw_dataset != "olist_raw"
        or candidate_dataset != "olist_raw_candidate"
    ):
        raise ValueError("Unexpected project or dataset configuration.")

    client = bigquery.Client(project=project)

    for dataset_name in (raw_dataset, candidate_dataset):
        dataset = client.get_dataset(f"{project}.{dataset_name}")
        if dataset.location.lower() != location.lower():
            raise ValueError(f"{dataset_name}: location mismatch.")

    failures = []

    for name in TABLES:
        try:
            raw_id = f"{project}.{raw_dataset}.{name}"
            candidate_id = (
                f"{project}.{candidate_dataset}.{name}__{args.run_id}"
            )

            columns = schemas["tables"][name]
            if (
                not columns
                or len(columns) != len(set(columns))
                or any(
                    not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", column)
                    for column in columns
                )
            ):
                raise ValueError("Invalid configured column names.")

            expected_schema = [
                (column, "STRING", "NULLABLE") for column in columns
            ]

            for table_id in (raw_id, candidate_id):
                table = client.get_table(table_id)
                actual_schema = [
                    (field.name, field.field_type, field.mode)
                    for field in table.schema
                ]
                if actual_schema != expected_schema:
                    raise ValueError(f"Schema mismatch: {table_id}")

            selected_columns = ", ".join(
                f"`{column}`" for column in columns
            )

            sql = f"""
                WITH raw_grouped AS (
                    SELECT
                        TO_JSON_STRING(t) AS row_contents,
                        COUNT(*) AS copies
                    FROM (
                        SELECT {selected_columns}
                        FROM `{raw_id}`
                    ) AS t
                    GROUP BY row_contents
                ),
                candidate_grouped AS (
                    SELECT
                        TO_JSON_STRING(t) AS row_contents,
                        COUNT(*) AS copies
                    FROM (
                        SELECT {selected_columns}
                        FROM `{candidate_id}`
                    ) AS t
                    GROUP BY row_contents
                )
                SELECT
                    COALESCE(SUM(r.copies), 0) AS raw_rows,
                    COALESCE(SUM(c.copies), 0) AS candidate_rows,
                    COUNTIF(
                        COALESCE(r.copies, 0) != COALESCE(c.copies, 0)
                    ) AS differing_row_groups
                FROM raw_grouped AS r
                FULL OUTER JOIN candidate_grouped AS c
                    ON r.row_contents = c.row_contents
            """

            job = client.query(
                sql,
                location=location,
                job_config=bigquery.QueryJobConfig(
                    use_legacy_sql=False,
                    use_query_cache=False,
                    maximum_bytes_billed=1_000_000_000,
                    labels={
                        "pipeline": "olist_ingestion",
                        "stage": "validation",
                        "run_id": args.run_id.lower(),
                    },
                ),
            )
            result = dict(next(iter(job.result())))

            passed = (
                result["raw_rows"] == result["candidate_rows"]
                and result["candidate_rows"] > 0
                and result["differing_row_groups"] == 0
            )

            print(
                json.dumps({
                    "table": name,
                    "run_id": args.run_id,
                    **result,
                    "status": "PASS" if passed else "REVIEW",
                    "query_job_id": job.job_id,
                }),
                flush=True,
            )

            if not passed:
                failures.append(name)

        except Exception as exc:
            failures.append(name)
            print(
                json.dumps({
                    "table": name,
                    "status": "ERROR",
                    "error": str(exc),
                }),
                flush=True,
            )

    if failures:
        raise SystemExit(
            "VALIDATION FAILED: " + ", ".join(failures)
            + ". Raw tables unchanged."
        )

    print(
        f"VALIDATION PASSED: all nine tables match raw "
        f"for run {args.run_id}. Raw tables unchanged.",
        flush=True,
    )


if __name__ == "__main__":
    main()