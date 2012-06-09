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
    has_many :budgets
    has_many :transactions
    has_many :statements
  end

  class Budget < ActiveRecord::Base
    # whitelist for mass assignment of attributes
    attr_accessible :carryover
    belongs_to :account
    has_many :transactions
    has_many :allotments
  end

  class Transaction < ActiveRecord::Base
    # whitelist for mass assignment of attributes
    attr_accessible :description
    belongs_to :account
    belongs_to :budget
  end

  class Statement < ActiveRecord::Base
    # whitelist for mass assignment of attributes
    attr_accessible :balance
    belongs_to :account
  end

  class Allotment < ActiveRecord::Base
    # whitelist for mass assignment of attributes
    attr_accessible :amount, :automatic, :start_date, :ends, :periods, :recur
    belongs_to :budget
  end

  # Contract:
  #   Requires that connection has been established to database
  class Records
      def initialize(path = "records.txt")
        raise LoadError unless File.exists?(path)
        @path = path
        @iuid = 0 # instance unique id
        @records = Hash.new
      end

      def print()
        pp @records
      end

      def load()
        file = File.open(@path)
        cols = nil
        row = nil
        compat_exc = Exception.new("Incompatible records format")

        file.each_line do |line|
          line.chomp!

          if '#' == line[0,1]
            cols = extract_columns(line)
            next
          end

          record = line.split('|')
          table_name = record.shift.capitalize # First field is table name
          raise compat_exc unless record.length == cols.length

          begin
            row = BudgetDB.const_get(table_name).new
          rescue
            raise compat_exc
          end

          cols.each_index do |i|
            # TODO: make foreign key references, but probably not right here in
            # the code

            #if '_id' == cols[i][-3,3]
            #    print row.id
            #end

            # ensure the column attribute exists in object, then set it
            raise compat_exc unless row.respond_to?(cols[i])
            row.write_attribute(cols[i], record[i])
          end

          add_record(row)

        end

        file.close
      end

    private

    def get_iuid()
      return (@iuid += 1).to_s
    end

    def get_iuid_dup_key(key)
      return key + "-dup-" + get_iuid
    end

    # Add record to the records hash
    #
    # If there is a duplicate import id, the original record is given a new
    # unique key that indicates it was generated as a result of a collision.
    # The first and all future collisions will also be given new keys. The
    # import id key in the records table will refer to the new key of the
    # original record for future duplicate record comparisons.
    #
    # Refactor?
    #  - A more idiomatic way of handling collisions would be to have a hash of
    #  lists. Collisions would be appended to the list.
    #
    # Requires:
    #   - row should not be null
    #
    # Guarantees:
    #   - the row will be added to the records hash (a duplicate record
    #   exception will be raised if all fields are duplicated; not just id)
    def add_record(row)
      key = row.respond_to?("import") ? row.import : get_iuid # set import id
      if @records.has_key?(key) # collision; non-unique id in input data
        is_table = @records[key].class < ActiveRecord::Base # if 1st collision
        a = is_table ? @records[key].attributes_before_type_cast.to_s
                     : @records[@records[key]].attributes_before_type_cast.to_s
        b = row.attributes_before_type_cast.to_s
        if a != b
          puts "WARNING: Duplicate record import id (import: #{key})"
          if is_table
            new_key = get_iuid_dup_key(key)   # get unique key for original
            @records[new_key] = @records[key] # move original to new key
            @records[key] = new_key           # set to new key of original
          end
          key = get_iuid_dup_key(key)         # get unique key for collision
        else
          raise "FATAL: Duplicate record: #{a}"
        end
      end
      @records[key] = row
    end

    def extract_columns(line = nil)
      return nil if nil == line
      line = line[1,line.length-1].lstrip!
      cols = line.split('|')
      cols.shift # drop first field (table)
      cols.each_index do |i|
        cols[i] = 'import' if 'id' == cols[i]
      end
      return cols
    end

  end

end

if __FILE__ == $0
end
