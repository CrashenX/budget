#!/usr/bin/env ruby
# Library to load accounts, transactions, & statements into a budget db
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

require 'active_record'

module BudgetDB
  def self.connect(password, db = "budget")
    ActiveRecord::Base.logger = Logger.new(STDERR)
    ActiveRecord::Base.establish_connection(
      :adapter  => "postgresql",
      :host     => "localhost",
      :username => `whoami`.strip,
      :password => password,
      :database => "budget"
    )
  end

  class Account < ActiveRecord::Base
    # whitelist for mass assignment of attributes
    attr_accessible :name, :tracked
  end

  class Budget < ActiveRecord::Base
    # whitelist for mass assignment of attributes
    attr_accessible :carryover
  end

  class Transaction < ActiveRecord::Base
    # whitelist for mass assignment of attributes
    attr_accessible :description
  end

  class Statement < ActiveRecord::Base
    # whitelist for mass assignment of attributes
    attr_accessible :balance
  end

  class Allotment < ActiveRecord::Base
    # whitelist for mass assignment of attributes
    attr_accessible :amount, :automatic, :start_date, :ends, :periods, :recur
  end
end

if __FILE__ == $0
end
