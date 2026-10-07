import subprocess
from datetime import timedelta

import pendulum
from airflow.sdk import dag, task


DBT = "/opt/airflow/dbt-venv/bin/dbt"
PROJECT = "/opt/dbt/project"
PROFILES = "/opt/airflow/config/dbt"

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
            "--project-dir", PROJECT,
            "--profiles-dir", PROFILES,
            "--target", "dev",
        ],
        cwd=PROJECT,
        check=True,
    )


@dag(
    dag_id="olist_dbt_marts",
    description="Validate upstream tables, then build and test reporting marts.",
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    schedule=None,
    catchup=False,
    max_active_runs=1,
    max_active_tasks=1,
    default_args={
        "retries": 0,
        "execution_timeout": timedelta(minutes=30),
    },
    tags=["olist", "dbt", "marts"],
)
def olist_dbt_marts():

    @task
    def check_connection():
        run_dbt(["debug"])

    @task
    def test_upstream():
        run_dbt([
            "test",
            "--select",
            "path:models/marts/facts",
            "path:models/marts/dimensions",
            "--indirect-selection", "buildable",
        ])

    @task
    def build_marts():
        run_dbt(["build", "--select", *MARTS])

    check_connection() >> test_upstream() >> build_marts()


olist_dbt_marts()