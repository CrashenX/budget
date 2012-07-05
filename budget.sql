-- Database schema for budget application
-- Copyright (C) 2012 Jesse J. Cook

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

DROP TABLE rules;
DROP TABLE allotments;
DROP TABLE statements;
DROP TABLE transactions;
DROP TABLE budgets;
DROP TABLE accounts;
DROP TYPE recur_type;
DROP TYPE transaction_type;
DROP TYPE account_type;

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
    import varchar unique,
    account_id integer references accounts,
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
    prev integer references rules,
    next integer references rules,
    budget_id integer references budgets not null,
    account_id integer references accounts,
    transaction_id integer references transactions,
    min_amount money,
    max_amount money,
    before date,
    after date,
    contains varchar,
    type transaction_type
);
