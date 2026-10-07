FROM apache/airflow:3.3.1

USER airflow

COPY --chown=airflow:root requirements-dbt.txt /opt/airflow/requirements-dbt.txt

RUN python -m venv /opt/airflow/dbt-venv \
    && /opt/airflow/dbt-venv/bin/python -m pip install \
        --no-cache-dir --no-user \
        -r /opt/airflow/requirements-dbt.txt \
    && /opt/airflow/dbt-venv/bin/python -m pip check