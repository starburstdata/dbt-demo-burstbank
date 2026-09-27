# BurstBank 2.0 workshop guide

This repo builds up in five checkpoints. Each branch below is independently
checkoutable and should `dbt build` cleanly on its own.

This guide lives on `main`, so it travels to every checkpoint branch — whichever
one you have checked out, the section for it is below. Note that the models and
files a section describes only exist from that checkpoint onward.

```bash
git checkout checkpoint-N
dbt deps && dbt seed && dbt build
```

## checkpoint-0: bronze/gold rename

The starting point: `staging/` and `marts/` renamed to `bronze/` and `gold/`,
with schema/tag config for the medallion layers and `persist_docs` turned on
project-wide. `persist_docs` writes dbt descriptions to Starburst table and
column comments — this is what lets an AI agent read them later, in
checkpoint-4.

`macros/generate_schema_name.sql` makes dbt use the `+schema` values from
`dbt_project.yml` verbatim. Without it, dbt's default prefixes them with the
profile's schema and everything lands in
`lakehouse.burstbank_dbt_burstbank_bronze` rather than
`lakehouse.burstbank_bronze`. That default also gives each developer their own
prefixed copy; the workshop doesn't need it because every attendee has their
own Galaxy trial account, but drop the macro if you ever point several people
at one catalog.

No new models yet; this is the same data as `main`, just relaid out.

## checkpoint-1: CRM source

Adds a `crm` source (`models/sources.yml`) and two bronze models,
`bronze_crm_interactions` and `bronze_crm_digital_activity`.

The `crm_mode` var controls where the source actually points:

- `crm_mode: seed` (default) — the source reads the tables `dbt seed`
  creates from `seeds/crm_interactions.csv` and `seeds/crm_digital_activity.csv`.
  This is what attendees use.
- `crm_mode: postgres` (presenter only) — the source reads a live Postgres
  `crm` catalog through Starburst federation. Nothing is copied ahead of time.

The model SQL is identical either way — only the source's resolved
database/schema changes.

**Optionality moment** (presenter):

```bash
# Federated: reads Postgres live, nothing is copied
dbt run -s bronze_crm_interactions --vars '{crm_mode: postgres}'

# Materialized: same model, now an Iceberg table. The SQL doesn't change.
dbt run -s bronze_crm_interactions --vars '{crm_mode: postgres, crm_bronze_materialization: table}'
```

Presenter setup for the `postgres` mode: add a PostgreSQL catalog named `crm`
in Galaxy, attach it to the workshop cluster, then load the CRM tables in one
of two ways:

- **From Galaxy (no `psql` needed):** paste `scripts/load_crm_trino.sql` into
  the Galaxy query editor and run its statements in order. The `crm` catalog
  must allow writes. The script drops and recreates the two CRM tables, so
  it's safe to re-run.
- **With `psql`:** run `scripts/load_crm_postgres.sql` against the Postgres
  database directly, from the repo root so its `\copy` paths resolve.

Both load the same rows as `seeds/*.csv`.

**Seed data note:** `seeds/*.csv` cover all 1,000 `sample.burstbank`
customers (`custkey` 1000001–1001000). They're produced by
`scripts/generate_crm_data.py`, which reads the customer keys in `custkey`
order and uses a fixed random seed, so re-running it reproduces the committed
files exactly. You only need to re-run it if the sample dataset's customers
change. To run it, `pip install -r requirements.txt`, set `GALAXY_HOST`, and
run `python scripts/generate_crm_data.py`. It signs in with Galaxy OAuth: a
browser window opens for the SSO login (the URL is also printed, in case no
browser opens). No password is needed. `GALAXY_USER` is optional.

## checkpoint-2: silver layer

Adds `models/silver/`:

- `slv_payments` — incremental Iceberg table (merge strategy, partitioned by
  `month(payment_date)`) that unions the three payment products. The bronze
  payment tables don't share a key or column set (`cc_number` / `mortgage_id`
  / `auto_loan_id`), so each product is explicitly mapped and joined to
  `stg_accounts` to attach `custkey`. `fct_payments` now reads from
  `slv_payments` instead of re-deriving the union itself; its output schema
  is unchanged, so `rpt_customer_risk` needed no changes.
- `slv_customer_360` — the core customer dimension joined with CRM signals:
  interactions/complaints in the last 90 days, and login trends over the
  last 6 months (`logins_last_3m` vs `logins_prior_3m`).

Note: the 90-day and 3-month windows are measured from the `as_of_date` var
(default **2026-09-29**, the date the CRM generator builds its data around),
not `current_date`. The results are therefore the same whatever day you
rehearse or present on. If you regenerate the seeds around a different date,
change `today` in `scripts/generate_crm_data.py` and `as_of_date` in
`dbt_project.yml` together. For a one-off, you can override it without
editing anything: `dbt build --vars '{as_of_date: "2026-10-15"}'`.

The login windows cover complete calendar months before `as_of_date`
(Jun–Aug vs Mar–May for the default), and the current partial month is
excluded. If you compare against a raw mid-month cutoff instead, the two
windows cover different numbers of months, and every steady customer picks up
a spurious ~33% engagement drop.

**Verify the incremental behavior** — run `slv_payments` twice and confirm a
second Iceberg snapshot was created:

```sql
select snapshot_id, committed_at, operation
from lakehouse."burstbank_silver"."slv_payments$snapshots"
order by committed_at desc;
```

The incremental filter is `payment_date >= max(payment_date)`, not `>`, so
each run re-reads the most recent day it already loaded. That's deliberate: a
payment that arrives late for that date still gets picked up, and the MERGE on
`payment_key` rewrites the rows already there rather than duplicating them.
It also makes the second run a better demo — the snapshot it commits contains
real updates, not just appends.

## checkpoint-3: gold data product

Adds `models/gold/dp_customer_retention_risk.sql` — the governed, contract-
enforced data product that's the target for the AI-agent finale. It combines
`slv_customer_360` (CRM engagement) with `rpt_customer_risk` (delinquency and
balances). `total_outstanding_balance` is computed as
`cc_balance + mortgage_balance + auto_loan_balance`, since `rpt_customer_risk`
doesn't carry a single pre-summed total. The risk score weights in the SQL
are illustrative, not a real model.

**Confirm `persist_docs` wrote the column comments:**

```sql
select column_name, comment
from lakehouse.information_schema.columns
where table_schema = 'burstbank_gold'
  and table_name = 'dp_customer_retention_risk';
```

## checkpoint-4: finale

Adds `analyses/agent_questions.sql` — ground truth for the three questions the
AI agent finale answers, run directly against `dp_customer_retention_risk`
(and `rpt_customer_risk` for Q3's mortgage balance).

## Merge checklist

- [ ] Spot-check that the CRM metrics in `dp_customer_retention_risk` are
      non-zero for most customers (confirms the seed `customer_id`s join to
      real `custkey`s)
- [ ] `dbt deps && dbt seed && dbt build` passes on a fresh Galaxy trial account
- [ ] Confirm `custkey`'s actual SQL type in `sample.burstbank.customer` via
      `information_schema.columns`, and correct the `data_type: bigint` guess
      in `models/gold/gold.yml` if it differs
- [ ] Contract types in `gold.yml` match what dbt-trino actually returns,
      especially `bigint` from `count`/`count_if`, the decimal precision on
      `total_outstanding_balance`, and the two pass-through varchars (`state`,
      `segment`) if their source columns turn out to be length-bounded
- [ ] `slv_payments`' `unique` test on `payment_key` passes on real data — if
      an account can pay twice in one day for the same amount, the key needs
      another column or the incremental MERGE will fail on the second run
- [ ] Incremental run on `slv_payments` creates a second snapshot
- [ ] Column comments visible in Starburst for the gold data product
- [ ] `crm_mode: postgres` run succeeds against the presenter `crm` catalog
- [ ] Checkpoint branches `checkpoint-0` to `checkpoint-4` build independently
