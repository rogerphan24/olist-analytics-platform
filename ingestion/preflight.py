import csv
import io
import json
from pathlib import Path

from google.cloud import bigquery, storage


CONFIG_DIR = Path(__file__).resolve().parent


def main():
    manifest = json.loads(
        (CONFIG_DIR / "sources.json").read_text(encoding="utf-8-sig")
    )
    schemas = json.loads(
        (CONFIG_DIR / "schemas.json").read_text(encoding="utf-8-sig")
    )

    sources = manifest["sources"]
    table_names = [source["table"] for source in sources]

    if len(table_names) != 9 or len(set(table_names)) != 9:
        raise ValueError("Expected nine distinct source tables.")

    if set(table_names) != set(schemas["tables"]):
        raise ValueError("Source manifest and schema table names differ.")

    if (
        schemas["default_type"] != "STRING"
        or schemas["default_mode"] != "NULLABLE"
    ):
        raise ValueError("Expected STRING, NULLABLE raw columns.")

    project = manifest["project_id"]
    dataset_id = f"{project}.{manifest['dataset_id']}"

    storage_client = storage.Client(project=project)
    bq_client = bigquery.Client(project=project)

    dataset = bq_client.get_dataset(dataset_id)
    if dataset.location.lower() != manifest["location"].lower():
        raise ValueError("BigQuery dataset location differs from the manifest.")

    bucket = storage_client.bucket(manifest["bucket"])

    for source in sources:
        table_name = source["table"]
        columns = schemas["tables"][table_name]

        if not columns or len(columns) != len(set(columns)):
            raise ValueError(f"{table_name}: empty or duplicate column names.")

        object_name = manifest["prefix"] + source["file"]
        blob = bucket.get_blob(object_name)

        if blob is None:
            raise ValueError(f"{table_name}: source object does not exist.")

        if not blob.size:
            raise ValueError(f"{table_name}: source object is empty.")

        # Read only the start of this specific object generation.
        header_bytes = blob.download_as_bytes(
            start=0,
            end=min(blob.size - 1, 65535),
            if_generation_match=int(blob.generation),
        )

        # These source headers occupy a single physical line.
        if b"\n" not in header_bytes:
            raise ValueError(f"{table_name}: no complete header line found.")

        header_line = header_bytes.split(b"\n", 1)[0].decode("utf-8-sig")
        header = next(csv.reader(io.StringIO(header_line), strict=True))

        if header != columns:
            raise ValueError(
                f"{table_name}: CSV header mismatch.\n"
                f"Expected: {columns}\n"
                f"Actual:   {header}"
            )

        table = bq_client.get_table(f"{dataset_id}.{table_name}")
        actual_schema = [
            (field.name, field.field_type, field.mode)
            for field in table.schema
        ]
        expected_schema = [
            (column, "STRING", "NULLABLE")
            for column in columns
        ]

        if actual_schema != expected_schema:
            raise ValueError(
                f"{table_name}: existing BigQuery schema differs "
                "from schemas.json."
            )

        print(
            f"PASS {table_name}: {len(columns)} columns; "
            f"bytes={blob.size}; generation={blob.generation}",
            flush=True,
        )

    print("Preflight passed: all nine sources checked. No data changed.")


if __name__ == "__main__":
    main()