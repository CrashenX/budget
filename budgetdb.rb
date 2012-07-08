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
require 'ostruct'
require 'pp'

module BudgetDB
  # Connect to the database
  def self.connect(password, db = "budget")
    ActiveRecord::Base.logger = Logger.new("db.log")
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

  # Save the database
  def self.save(message, db = "budget", dir = "history")
    begin
      file = db + ".sql"
      system("pg_dump", "-f", "#{dir}/#{file}", db)
      Dir.chdir(dir) do
        system("git", "add", file)
        system("git", "commit", "-m", message)
      end
    rescue
      raise
    end
  end

  class Account < ActiveRecord::Base
    ActiveRecord::Base.inheritance_column = "itype" # using type (default col)
    # whitelist for mass assignment of attributes
    attr_accessible :name, :tracked
    validates_uniqueness_of :import, :name
    has_many :budgets
    has_many :transactions
    has_many :statements
  end

  class Budget < ActiveRecord::Base
    # whitelist for mass assignment of attributes
    attr_accessible :carryover
    validates_uniqueness_of :name
    belongs_to :account
    has_many :transactions
    has_many :allotments
  end

  class Transaction < ActiveRecord::Base
    ActiveRecord::Base.inheritance_column = "itype" # using type (default col)
    # whitelist for mass assignment of attributes
    attr_accessible :display
    validates_uniqueness_of :import
    belongs_to :account
    belongs_to :budget
  end

  class Statement < ActiveRecord::Base
    # whitelist for mass assignment of attributes
    validates_uniqueness_of :account_id, :scope => [:start_date, :end_date]
    belongs_to :account
  end

  class Allotment < ActiveRecord::Base
    # whitelist for mass assignment of attributes
    attr_accessible :amount, :automatic, :start_date, :ends, :periods, :recur
    belongs_to :budget
  end

  class Rule < ActiveRecord::Base
    has_many :conditions
    has_many :rules
  end

  class Condition < ActiveRecord::Base
    # whitelist for mass assignment of attributes
    attr_accessible :key, :op, :value
    belongs_to :rule
  end

  class Action < ActiveRecord::Base
    # whitelist for mass assignment of attributes
    attr_accessible :key, :value
    belongs_to :rule
  end


  # Contract:
  #   Requires that connection has been established to database
  class Classify
    def initialize()
      @rules = Array.new
    end

    # Load all of the rules (in order) from the database
    def load()
      first = BudgetDB::Rule.find_by_prev(nil)
      id = first ? first.id : nil
      while nil != id
        rule = BudgetDB::Rule.find_by_id(id)
        raise ActiveRecord::RecordNotFound if nil == rule
        conditions = BudgetDB::Condition.find_all_by_rules_id(id)
        raise ActiveRecord::RecordNotFound if 0 == conditions.length
        actions = BudgetDB::Action.find_all_by_rules_id(id)
        raise ActiveRecord::RecordNotFound if 0 == actions.length
        @rules.push(OpenStruct.new(:conditions => conditions,
                                   :actions => actions))
        id = rule.next
      end
      #apply_rule(@rules.first)
    end

    def apply_rule(rule)
      where = Array.new
      set   = Array.new
      where.push rule.conditions.map{|c| c.key+" "+c.op+" ?"}.join(" and ")
      where += rule.conditions.map{|c| c.value}
      set.push rule.actions.map{|c| c.key + " ?"}.join(", ")
      set += rule.actions.map{|c| c.value}
      #puts where.to_s
      #puts set.to_s
    end
  end

  # Contract:
  #   Requires that connection has been established to database
  class Records
    def initialize()
      @iuid = 0 # instance unique id
      @records = Hash.new
      @belongs2 = Array.new
    end

    def print()
      pp @records
    end

    # Load all of the transactions from the specified file
    def load(path = "records.txt")
      raise LoadError unless File.exists?(path)
      file = File.open(path)
      cols = nil
      row = nil
      compat_exc = Exception.new("Incompatible records format")
      file.each_line do |line|
        fkeys = Array.new
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
          # ensure the column attribute exists in object, then set it
          raise compat_exc unless row.respond_to?(cols[i])
          if '_id' == cols[i][-3,3] # gather imported fks for conversion
            fkeys.push([cols[i][0...-3], record[i]])
          else
            row.write_attribute(cols[i], record[i])
          end
        end
        key = add_record(row)
        fkeys.each do |fk|
          @belongs2.push(OpenStruct.new(:import_id => key,
            :ftable_name => fk.first, :fk_import_id => fk.last))
        end
      end
      file.close
      establish_relationships
    end

    # Save the loaded records to the database
    def save
      @records.each_value do |r|
        r.save
      end
    end

    private

    # Establish relationships between tables (set foreign keys)
    def establish_relationships
      relation_exc = Exception.new("Invalid or missing foreign key")
      @belongs2.each do |r|
        table = r.ftable_name.capitalize
        ftable = BudgetDB.const_get(table).find_by_import(r.fk_import_id)
        if nil == ftable
          ftable = @records[r.fk_import_id]
        end
        if nil == ftable
          throw relation_exc
        end
        record = @records[r.import_id]
        record.send("#{r.ftable_name}=", ftable)
      end
    end

    # Get an instance unique id
    def get_iuid()
      return (@iuid += 1).to_s
    end

    # Add record to the records hash
    #
    # Requires:
    #   - row should not be null
    #
    # Guarantees:
    #   - the row will be added to the records hash (a duplicate record
    #   exception will be raised if there is a duplicate)
    def add_record(row)
      key = row.respond_to?("import") ? row.import : get_iuid # set import id
      if @records.has_key?(key) # collision; non-unique id in input data
        a = @records[key].attributes_before_type_cast.to_s
        b = row.attributes_before_type_cast.to_s
        if a != b
          raise "ERROR: Duplicate import id (import: #{key})"
        else
          raise "ERROR: Duplicate record: #{a}"
        end
      end
      @records[key] = row
      return key
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
