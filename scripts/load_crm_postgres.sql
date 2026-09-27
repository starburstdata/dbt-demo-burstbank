-- Run with psql from the repo root (the \copy paths are relative to it).
-- The tables go in schema `crm`, which Galaxy reads as postgresql.crm.

create schema if not exists crm;

create table if not exists crm.crm_interactions (
    interaction_id   bigint primary key,
    customer_id      varchar(32),
    interaction_ts   timestamp,
    channel          varchar(16),
    reason           varchar(32),
    is_complaint     boolean,
    sentiment_score  numeric(4,2)
);

create table if not exists crm.crm_digital_activity (
    customer_id      varchar(32),
    activity_month   date,
    logins           integer,
    bill_pay_events  integer,
    app_rating       integer
);

\copy crm.crm_interactions from 'seeds/crm_interactions.csv' csv header
\copy crm.crm_digital_activity from 'seeds/crm_digital_activity.csv' csv header
