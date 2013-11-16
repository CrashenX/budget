-- Database schema for budget application
-- Copyright (C) 2013 Jesse J. Cook

-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Affero General Public License as
-- published by the Free Software Foundation, either version 3 of the
-- License, or (at your option) any later version.

-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Affero General Public License for more details.

-- You should have received a copy of the GNU Affero General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

CREATE TYPE account_type AS ENUM
(
    'CHECKING',
    'SAVINGS',
    'CREDITCARD'
);

CREATE TYPE transaction_type AS ENUM
(
    'ATM',
    'CHECK',
    'CREDIT',
    'DEBIT',
    'DEP',
    'DIRECTDEP',
    'INT',
    'POS',
    'XFER'
);

CREATE TYPE recur_type AS ENUM
(
    'DAILY',
    'WEEKLY',
    'BIWEEKLY',   -- Every other week
    'MONTHLY',
    'BIMONTHLY',  -- Every other month
    'QUARTERLY',
    'BIANNUALLY', -- Every six months
    'ANNUALLY'
);

CREATE TYPE condition_key AS ENUM
(
    'account_id',
    'amount',
    'date',
    'description',
    'id',
    'import',
    'type'
);

CREATE TYPE action_key AS ENUM
(
    'budget_id',
    'display'
);

CREATE TYPE operator AS ENUM
(
    '<=',
    '>=',
    '=',
    '~*'
);

CREATE TABLE accounts
(
    id serial primary key,
    import varchar unique,
    type account_type,
    number varchar,
    name varchar,
    tracked boolean
);

CREATE TABLE budgets
(
    id serial primary key,
    name varchar unique,
    carryover boolean,
    balance money
);

CREATE TABLE transactions
(
    id serial primary key,
    import varchar unique,
    account_id integer references accounts not null,
    date date,
    type transaction_type,
    amount money,
    description text,
    display text,
    budget_id integer references budgets
);

CREATE TABLE statements
(
    id serial primary key,
    account_id integer references accounts not null,
    start_date date,
    end_date date,
    balance money,
    unique (account_id, start_date, end_date)
);

CREATE TABLE allotments
(
    id serial primary key,
    budget_id integer references budgets,
    amount money,
    automatic boolean,
    start_date date,
    ends boolean,
    periods integer,
    recur recur_type
);

CREATE TABLE rules
(
    id serial primary key,
    prev_id integer references rules,
    next_id integer references rules
);

CREATE TABLE conditions
(
    id serial primary key,
    rule_id integer references rules not null,
    key condition_key not null,
    op operator not null,
    value varchar not null
);

CREATE TABLE actions
(
    id serial primary key,
    rule_id integer references rules not null,
    key action_key not null,
    value varchar not null
);
