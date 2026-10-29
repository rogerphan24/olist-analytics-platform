import subprocess
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import pendulum
from airflow.sdk import dag, task


PYTHON = "/opt/airflow/dbt-venv/bin/python"
INGESTION = "/opt/olist/ingestion"


@dag(
    dag_id="olist_ingestion_candidates",
    description="Load candidate raw tables and validate against existing raw.",
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    schedule=None,
    catchup=False,
    max_active_runs=1,
    max_active_tasks=1,
    default_args={
        "retries": 0,
        "execution_timeout": timedelta(minutes=30),
    },
    tags=["olist", "ingestion", "candidate"],
)
def olist_ingestion_candidates():
    @task
    def create_run_id():
        run_id = (
            datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S")
            + "_"
            + uuid4().hex[:8]
        )
        print(f"Candidate run ID: {run_id}", flush=True)
        return run_id

    @task(retries=2, retry_delay=timedelta(minutes=1))
    def load_candidates(candidate_run_id: str):
        subprocess.run(
            [
                PYTHON,
                "-u",
                f"{INGESTION}/load_candidates.py",
                "--run-id",
                candidate_run_id,
            ],
            check=True,
        )
        return candidate_run_id

    @task(retries=2, retry_delay=timedelta(minutes=1))
    def validate_candidates(candidate_run_id: str):
        subprocess.run(
            [
                PYTHON,
                "-u",
                f"{INGESTION}/validate_candidates.py",
                "--run-id",
                candidate_run_id,
            ],
            check=True,
        )
        print(
            f"Candidate run {candidate_run_id} validated. Raw tables unchanged.",
            flush=True,
        )

    run_id = create_run_id()
    loaded_run_id = load_candidates(run_id)
    validate_candidates(loaded_run_id)


olist_ingestion_candidates()