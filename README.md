# burstbank dbt project

A dbt project built on the Starburst Galaxy `sample.burstbank` dataset — a fictional retail bank with customers, accounts, and payment history across three product lines: credit cards, mortgages, and auto loans.

> **Running the BurstBank 2.0 workshop?** See [WORKSHOP.md](WORKSHOP.md). The
> workshop builds this project up into a bronze/silver/gold medallion with a
> federated CRM source and a governed data product, across the
> `checkpoint-0` … `checkpoint-4` branches.

## Prerequisites

- Python 3.9+
- A Starburst Galaxy cluster with access to the `sample` catalog and write access to a `lakehouse` catalog
- A `lakehouse` catalog configured in your Galaxy cluster (Iceberg recommended)

## Setup

### 1. Install dependencies

```bash
pip install -r requirements.txt
dbt deps
```

### 2. Configure your profile

Copy `sample.profiles.yml` to `~/.dbt/profiles.yml` and set the required environment variables:

```bash
export GALAXY_HOST=<your-cluster-host>.trino.galaxy.starburst.io
export GALAXY_USER=you@example.com
export GALAXY_PASSWORD=your-password
```

### 3. Verify the connection

```bash
dbt debug
```

## Running the project

```bash
dbt run       # build all models
dbt test      # run schema tests
dbt docs generate && dbt docs serve   # browse the data catalog
```

To build a single layer:

```bash
dbt run --select bronze
dbt run --select gold
```

## Project structure

```
models/
├── sources.yml          # points to sample.burstbank (read-only source)
├── bronze/              # one materialized view per source table, written to lakehouse.burstbank_bronze
│   ├── stg_accounts.sql
│   ├── stg_auto_loan_payments.sql
│   ├── stg_credit_card_payments.sql
│   ├── stg_customer_profiles.sql
│   ├── stg_customers.sql
│   ├── stg_employees.sql
│   ├── stg_mortgage_payments.sql
│   ├── stg_product_profiles.sql
│   └── stg_state_census.sql
└── gold/                # analytics-ready tables, written to lakehouse.burstbank_gold
    ├── dim_customers.sql
    ├── fct_payments.sql
    └── rpt_customer_risk.sql
```

## Data model

### Sources (`sample.burstbank`)

| Table | Description |
|---|---|
| `customer` | Customer demographics — name, address, DOB, FICO score |
| `account` | Per-customer account holding credit card, mortgage, and auto loan identifiers and balances |
| `customer_profile` | Customer segmentation — career, risk appetite, segment |
| `product_profile` | Product details — rates, loan officers, durations, vehicle/residence type |
| `credit_card_payment` | Credit card payment history |
| `mortgage_payment` | Mortgage payment history |
| `auto_loan_payment` | Auto loan payment history |
| `employee` | Bank employees, used to resolve loan officer names |
| `state_census` | US state population estimates for geographic enrichment |

### Bronze (`lakehouse.burstbank_bronze`)

Materialized views that clean the source layer (Starburst stores each result, and dbt refreshes it on every run): varchar dates are cast to `date`, boolean flags (`Y`/`N`) are cast to booleans, and the `manger_id` typo in the `employee` table is corrected to `manager_id`.

### Gold (`lakehouse.burstbank_gold`)

| Model | Description |
|---|---|
| `dim_customers` | Customer dimension joining demographics, segmentation, and state census data |
| `fct_payments` | All payment events across credit cards, mortgages, and auto loans in a single table, with a `product_type` column and delinquency flag |
| `rpt_customer_risk` | Customer-level risk summary: total payments, delinquent payment count, delinquency rate, and outstanding balance by product |

## Catalog layout

| | Catalog | Schema |
|---|---|---|
| Source data (read-only) | `sample` | `burstbank` |
| Bronze materialized views | `lakehouse` | `burstbank_bronze` |
| Gold tables | `lakehouse` | `burstbank_gold` |
