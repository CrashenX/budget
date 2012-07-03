#!/usr/bin/env ruby
# Budget management tool
# Copyright (C) 2012 Jesse J. Cook
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require_relative 'budgetdb'
require_relative 'cmdopts'

if __FILE__ == $0
  options = CmdOpts.parse(ARGV)

  begin
    db = BudgetDB.connect(options.password)
  rescue Exception => err
    puts "Database connection failed: " + err.to_s
    exit 1
  end

  records = BudgetDB::Records.new
  # begin
  #   records.load
  # rescue Exception => err
  #     puts "Failed to load records: " + err.to_s
  #     exit 1
  # end
  records.load
  records.print

  if options.insert
    BudgetDB::Statement.create(:balance  => '123.45');

    s = BudgetDB::Statement.new()
    s.balance = '123.45'
    s.save
  end

  if options.show
    puts BudgetDB::Statement.find_all_by_balance('123.45').count
  end
end
