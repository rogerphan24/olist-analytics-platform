import pendulum

from airflow.sdk import dag, task


@dag(
    dag_id="olist_smoke_test",
    description="Verify local Airflow task execution without accessing GCP.",
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    schedule=None,
    catchup=False,
    max_active_runs=1,
    tags=["olist", "setup"],
)
def olist_smoke_test():

    @task
    def check_execution():
        print("Olist Airflow smoke test passed.")

    check_execution()


olist_smoke_test()
