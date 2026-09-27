"""Generate CRM data keyed to real sample.burstbank customers.

Presenter: load the output into Postgres, either with psql
(load_crm_postgres.sql) or from the Galaxy query editor (load_crm_trino.sql,
which this script also writes). Attendees: the CSVs are committed to seeds/.

Signs in to Galaxy with OAuth: a browser window opens for the SSO login, and
the login URL is printed too in case no browser opens. Needs GALAXY_HOST;
GALAXY_USER is optional.
"""
import csv, os, random
from datetime import datetime, timedelta, date
import trino

random.seed(29)  # fixed seed so everyone gets the same results

conn = trino.dbapi.connect(
    host=os.environ["GALAXY_HOST"], port=443, http_scheme="https",
    user=os.environ.get("GALAXY_USER"),  # optional: OAuth identifies you from the login token
    auth=trino.auth.OAuth2Authentication(),
    catalog="sample", schema="burstbank",
)
cur = conn.cursor()
# Deterministic order: the random draws below are assigned to customers in
# this order, so an unordered or randomly ordered fetch would give different
# CSVs on every run despite the fixed seed.
cur.execute("select custkey from customer order by custkey limit 5000")
customers = [str(r[0]) for r in cur.fetchall()]

today = date(2026, 9, 29)
reasons = ["fees", "rates", "service", "close_account", "other"]
channels = ["call", "chat", "branch", "email"]

os.makedirs("seeds", exist_ok=True)

with open("seeds/crm_interactions.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["interaction_id", "customer_id", "interaction_ts", "channel",
                "reason", "is_complaint", "sentiment_score"])
    iid = 0
    for c in customers:
        at_risk = random.random() < 0.12          # about 12% of customers get an at-risk story
        for _ in range(random.randint(3, 8) if at_risk else random.randint(0, 3)):
            iid += 1
            reason = random.choices(reasons, [3, 2, 2, 2, 1] if at_risk else [2, 2, 3, 0.1, 3])[0]
            ts = (datetime.combine(today, datetime.min.time())
                  - timedelta(days=random.randint(0, 180), minutes=random.randint(0, 1440)))
            w.writerow([iid, c, ts.isoformat(sep=" "), random.choice(channels), reason,
                        at_risk and random.random() < 0.6,
                        round(random.uniform(-1, -0.2) if at_risk else random.uniform(-0.3, 1), 2)])

with open("seeds/crm_digital_activity.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["customer_id", "activity_month", "logins", "bill_pay_events", "app_rating"])
    for c in customers:
        base = random.randint(8, 40)
        decline = random.random() < 0.15
        for m in range(6, 0, -1):
            # the 6 whole calendar months before today's month (30-day steps
            # would skip or repeat a month depending on the date)
            y, mo = divmod(today.year * 12 + today.month - 1 - m, 12)
            month = date(y, mo + 1, 1)
            factor = (m / 6) if decline else random.uniform(0.85, 1.15)
            w.writerow([c, month.isoformat(), max(0, int(base * factor)),
                        random.randint(0, 6), random.randint(1, 5)])


# --- Trino version of the Postgres load -------------------------------------
# scripts/load_crm_trino.sql loads the same rows into Postgres, through its
# Galaxy catalog, from the Galaxy query editor, as an alternative to running load_crm_postgres.sql with
# psql. It's built from the CSVs just written, so the two can't drift apart.
# Every value is parsed and re-emitted as a typed literal, so a malformed row
# fails here instead of producing broken SQL.

ROWS_PER_INSERT = 1000  # keeps each statement far below Trino's query-length limit

# Galaxy catalog.schema holding the live CRM tables. Keep in step with
# crm_catalog / crm_schema in dbt_project.yml.
CRM_TABLE_PREFIX = "postgresql.crm"


def sql_str(v):
    return "'" + v.replace("'", "''") + "'"


def interaction_row(r):
    return "({}, {}, timestamp {}, {}, {}, {}, {:.2f})".format(
        int(r["interaction_id"]),
        sql_str(r["customer_id"]),
        sql_str(datetime.fromisoformat(r["interaction_ts"]).isoformat(sep=" ")),
        sql_str(r["channel"]),
        sql_str(r["reason"]),
        {"True": "true", "False": "false"}[r["is_complaint"]],
        float(r["sentiment_score"]),
    )


def digital_row(r):
    return "({}, date {}, {}, {}, {})".format(
        sql_str(r["customer_id"]),
        sql_str(date.fromisoformat(r["activity_month"]).isoformat()),
        int(r["logins"]),
        int(r["bill_pay_events"]),
        int(r["app_rating"]),
    )


def inserts(table, columns, rows):
    for i in range(0, len(rows), ROWS_PER_INSERT):
        yield "insert into {} ({})\nvalues\n{};\n".format(
            table, ", ".join(columns), ",\n".join(rows[i:i + ROWS_PER_INSERT]))


with open("seeds/crm_interactions.csv", newline="") as f:
    interactions = [interaction_row(r) for r in csv.DictReader(f)]
with open("seeds/crm_digital_activity.csv", newline="") as f:
    digital = [digital_row(r) for r in csv.DictReader(f)]

with open("scripts/load_crm_trino.sql", "w") as f:
    catalog = CRM_TABLE_PREFIX.split(".")[0]
    f.write("""\
-- Loads the CRM tables into Postgres through the Galaxy `{catalog}` catalog: paste
-- into the Galaxy query editor and run the statements in order. Alternative to
-- load_crm_postgres.sql for when you don't have psql access to the database.
--
-- Needs: a PostgreSQL catalog named `{catalog}`, attached to your cluster, that
-- allows writes. To target a different catalog.schema, change CRM_TABLE_PREFIX
-- in scripts/generate_crm_data.py and re-run it rather than editing this file.
--
-- DROPS AND RECREATES {p}.crm_interactions and {p}.crm_digital_activity,
-- so re-running it doesn't duplicate rows.
--
-- Generated by scripts/generate_crm_data.py from seeds/*.csv -- don't edit by hand.

create schema if not exists {p};

drop table if exists {p}.crm_interactions;

create table {p}.crm_interactions (
    interaction_id   bigint,
    customer_id      varchar(32),
    interaction_ts   timestamp(6),
    channel          varchar(16),
    reason           varchar(32),
    is_complaint     boolean,
    sentiment_score  decimal(4, 2)
);

drop table if exists {p}.crm_digital_activity;

create table {p}.crm_digital_activity (
    customer_id      varchar(32),
    activity_month   date,
    logins           integer,
    bill_pay_events  integer,
    app_rating       integer
);
""".format(catalog=catalog, p=CRM_TABLE_PREFIX))
    for stmt in inserts(CRM_TABLE_PREFIX + ".crm_interactions",
                        ["interaction_id", "customer_id", "interaction_ts", "channel",
                         "reason", "is_complaint", "sentiment_score"], interactions):
        f.write("\n" + stmt)
    for stmt in inserts(CRM_TABLE_PREFIX + ".crm_digital_activity",
                        ["customer_id", "activity_month", "logins", "bill_pay_events",
                         "app_rating"], digital):
        f.write("\n" + stmt)
    f.write("""
-- Check: expect {n_i} and {n_d} rows.
select 'crm_interactions' as table_name, count(*) as row_count from {p}.crm_interactions
union all
select 'crm_digital_activity', count(*) from {p}.crm_digital_activity;
""".format(n_i=len(interactions), n_d=len(digital), p=CRM_TABLE_PREFIX))
