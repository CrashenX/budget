-- Drop DB SQL for budget application
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

DROP TABLE conditions;
DROP TABLE actions;
DROP TABLE rules;
DROP TABLE allotments;
DROP TABLE statements;
DROP TABLE transactions;
DROP TABLE budgets;
DROP TABLE accounts;
DROP TYPE condition_key;
DROP TYPE action_key;
DROP TYPE operator;
DROP TYPE recur_type;
DROP TYPE transaction_type;
DROP TYPE account_type;
