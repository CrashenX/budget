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

CREATE DATABASE budgetdb;

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
    'DIRECTDEP',
    'INT',
    'POS',
    'XFER'
);

CREATE TYPE recur_type AS ENUm
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

-- TRANSACTION: table|id|account_id|date|type|amount|description
CREATE TABLE transactions
(
    id varchar,
    account_id varchar,
    date date,
    type transaction_type,
    amount money,
    import_description text,
    description text,
    budget_id integer
);

-- ACCOUNT: table|id|type|number|bank_id
CREATE TABLE accounts
(
    id varchar,
    type account_type,
    number varchar,
    bank_id varchar,
    name varchar,
    tracked boolean
);

-- STATEMENT: table|account_id|start_date|end_date|balance
CREATE TABLE statements
(
    id serial,
    account_id varchar,
    start_date date,
    end_date date,
    balance money
);

CREATE TABLE budgets
(
  id serial,
  account_id varchar,
  carryover boolean,
  balance money
);

CREATE TABLE allotments
(
    budget_id integer,
    amount money,
    automatic boolean,
    start_date date,
    ends boolean,
    periods integer,
    recur recur_type
);
