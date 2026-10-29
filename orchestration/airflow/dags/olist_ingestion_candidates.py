import subprocess
from datetime import datetime, timedelta, timezone
from sys import audit
from uuid import uuid4

import pendulum
from airflow.sdk import dag, task, get_current_context

import json
from functools import wraps


PYTHON = "/opt/airflow/dbt-venv/bin/python"
INGESTION = "/opt/olist/ingestion"
DBT = "/opt/airflow/dbt-venv/bin/dbt"
DBT_PROJECT = "/opt/dbt/project"
DBT_PROFILES = "/opt/airflow/config/dbt"

MARTS = [
    "mart_daily_sales",
    "mart_product_sales_daily",
    "mart_seller_sales_daily",
    "mart_delivery_daily",
    "mart_payments_daily",
    "mart_order_quality_daily",
    "mart_reviews_daily",
    "mart_customer_daily",
    "mart_customer_periods",
    "mart_category_sales_daily",
]

def run_dbt(arguments):
    subprocess.run(
        [
            DBT,
            *arguments,
            "--project-dir", DBT_PROJECT,
            "--profiles-dir", DBT_PROFILES,
            "--target", "dev",
        ],
        cwd=DBT_PROJECT,
        check=True,
    )

#Audit tasks
def audit_task(function):
    @wraps(function)
    def wrapped(*args, **kwargs):
        ti = get_current_context()["ti"]

        def emit(event_type, result=None, details=None):
            if ti.task_id == "create_run_id":
                candidate_id = result
                snapshot = None
            else:
                candidate_id = ti.xcom_pull(
                    task_ids="create_run_id",
                    key="return_value",
                )
                snapshot = ti.xcom_pull(
                    task_ids="load_candidates",
                    key="source_snapshot",
                )

            payload = {
                "dag_id": ti.dag_id,
                "airflow_run_id": ti.run_id,
                "candidate_run_id": candidate_id,
                "task_id": ti.task_id,
                "try_number": ti.try_number,
                "event_type": event_type,
                "source_snapshot": snapshot,
                "details": details or {},
            }

            subprocess.run(
                [
                    PYTHON,
                    "-u",
                    f"{INGESTION}/write_pipeline_events.py",
                ],
                input=json.dumps(payload),
                text=True,
                check=True,
                timeout=180,
            )

        emit("TASK_STARTED")

        try:
            result = function(*args, **kwargs)
        except Exception as exc:
            details = {"exception_type": type(exc).__name__}
            if isinstance(exc, subprocess.CalledProcessError):
                details["return_code"] = exc.returncode

            try:
                emit("TASK_FAILED", details=details)
            except Exception as audit_error:
                print(
                    "Failure event could not be recorded: "
                    f"{type(audit_error).__name__}",
                    flush=True,
                )
            raise

        emit("TASK_SUCCEEDED", result=result)
        return result

    return wrapped


   
# dag tasks for Airflow orchestration
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
    @audit_task
    def create_run_id():
        run_id = (
            datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S")
            + "_"
            + uuid4().hex[:8]
        )
        print(f"Candidate run ID: {run_id}", flush=True)
        return run_id

    @task(retries=2, retry_delay=timedelta(minutes=1))
    @audit_task
    def load_candidates(candidate_run_id: str):
        command = [
            PYTHON,
            "-u",
            f"{INGESTION}/load_candidates.py",
            "--run-id",
            candidate_run_id,
        ]

        with subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        ) as process:
            for line in process.stdout:
                print(line, end="", flush=True)

                if line.startswith("SOURCE SNAPSHOT:"):
                    snapshot = line.split(":", 1)[1].strip()
                    get_current_context()["ti"].xcom_push(
                        key="source_snapshot",
                        value=snapshot,
                    )

            return_code = process.wait()

        if return_code != 0:
            raise subprocess.CalledProcessError(
                return_code, command
            )

        return candidate_run_id

    @task(retries=2, retry_delay=timedelta(minutes=1))
    @audit_task
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


    @task
    @audit_task
    def check_dbt_connection():
        run_dbt(["debug"])

    @task(execution_timeout=timedelta(minutes=60))
    @audit_task
    def build_warehouse():
        run_dbt([
            "build",
            "--select",
            "path:models/staging",
            "path:models/marts/dimensions",
            "path:models/marts/facts",
            *MARTS,
            "--indirect-selection", "buildable",
        ])
    
    @task
    @audit_task
    def restore_and_verify_constraints():
        subprocess.run(
            [
                PYTHON,
                "-u",
                f"{INGESTION}/restore_constraints.py"
            ],
            check=True,
        )

    run_id = create_run_id()
    loaded_run_id = load_candidates(run_id)
    validated = validate_candidates(loaded_run_id)

    (
        validated
        >> check_dbt_connection()
        >> build_warehouse()
        >> restore_and_verify_constraints()
    )



olist_ingestion_candidates()