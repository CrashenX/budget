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
require 'pp'

module BudgetDB
  def self.connect(password, db = "budget")
    ActiveRecord::Base.logger = Logger.new(STDERR)
    begin
      ActiveRecord::Base.establish_connection(
        :adapter  => "postgresql",
        :host     => "localhost",
        :username => `whoami`.strip,
        :password => password,
        :database => "budget"
      )
      Account.table_exists? # Force connection now
    rescue
      raise
    end
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

  # Contract:
  #   Requires that connection has been established to database
  class Records
      def initialize(path = "records.txt")
        raise LoadError unless File.exists?(path)
        @path = path
      end

      def load()
        @records = Hash.new

        file = File.open(@path)
        cols = nil
        table = nil

        file.each_line do |line|
          line.chomp!

          # Extract columns
          if('#' == line[0,1])
            line = line[1,line.length-1].lstrip!
            cols = line.split('|')
            cols.shift
            next
          end

          record = line.split('|')
          table_name = record.shift.capitalize
          raise Encoding::CompatibilityError unless record.length == cols.length

          begin
            table = BudgetDB.const_get(table_name).new
            cols.each_index do |i|
              puts cols[i] + " == fail" unless table.respond_to?(cols[i])
              table.instance_variable_set("@#{cols[i]}", record[i])
              puts cols[i] + ":" + table.instance_variable_get("@#{cols[i]}")
            end
            #table.save
          rescue
            raise Encoding::CompatibilityError
          end

        end

        file.close

      end
  end
end

if __FILE__ == $0
end
