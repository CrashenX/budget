#!/usr/bin/env ruby1.9.1
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
  def self.connect(password, username = `whoami`.strip, database = "budget")
    ActiveRecord::Base.logger = Logger.new("db.log")
    begin
      ActiveRecord::Base.establish_connection(
        :adapter  => "postgresql",
        :host     => "localhost",
        :username => username,
        :password => password,
        :database => database
      )
      Account.table_exists? # Force connection now
    rescue
      raise
    end
    return
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
    validates_uniqueness_of :import
    has_many :transactions
    has_many :statements
  end

  class Budget < ActiveRecord::Base
    # whitelist for mass assignment of attributes
    attr_accessible :carryover
    validates_uniqueness_of :name
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
    attr_accessible
    validates_uniqueness_of :account_id, :scope => [:start_date, :end_date]
    belongs_to :account
  end

  class Allotment < ActiveRecord::Base
    # whitelist for mass assignment of attributes
    attr_accessible :amount, :automatic, :start_date, :ends, :periods, :recur
    belongs_to :budget
  end

  class Rule < ActiveRecord::Base
    # whitelist for mass assignment of attributes
    attr_accessible
    belongs_to :prev, :class_name => 'Rule', :foreign_key => 'prev_id'
    belongs_to :next, :class_name => 'Rule', :foreign_key => 'next_id'
    has_many :conditions
    has_many :actions

    def destroy()
        self.unlink
        self.conditions.map {|c| c.delete}
        self.actions.map {|a| a.delete}
        self.delete
    end

    def link_and_save()
      check_constraints
      ActiveRecord::Base.transaction do
        curr_rule = BudgetDB::Rule.find_by_id(self.id)
        if curr_rule && self.prev_id == curr_rule.prev_id
          self.next_id = curr_rule.next_id
          self.save
        else
          self.unlink
          self.save
          self.link
        end
      end
    end

    # Unlinks the rule in the database
    #
    # Requires:
    #   - The existence of a valid database connection
    #   - The rules table to be a fully-connected doubly-linked list with
    #   exactly one head and one tail
    #
    # Guarantees:
    #   - Self's neighbors will no longer point to the rule in the db
    #   - Self's neighbors will point to each other in the db
    #   - Self will be unchanged (both the object and in the database)
    #   - The unlink will happen transactionally
    #   - Nothing will be done if self is new (not in the database)
    def unlink()
      return if self.new_record?
      ActiveRecord::Base.transaction do
        curr_rule = BudgetDB::Rule.find_by_id(self.id)
        if curr_rule.prev(true) # load prev from db
          curr_rule.prev.next_id = curr_rule.next_id
          curr_rule.prev.save
        end
        if curr_rule.next(true) # load next from db
          curr_rule.next.prev_id = curr_rule.prev_id
          curr_rule.next.save
        end
      end
      return
    end

    # Links the rule in the database
    #
    # Requires:
    #   - The existence of a valid database connection
    #   - Self to exists in the database
    #   - Self to be unlinked (no other rule points to it)
    #   - The rules table to be a fully-connected doubly-linked list with
    #   exactly one head and one tail (excluding self)
    #   - The prev_id of self to be set to the id of the desired predessor,
    #   nil if it is to be the first Rule
    #
    # Guarantees:
    #   - Self will be linked in after the rule indicated by prev_id
    #   - Self will be the first rule if prev_id is nil
    #   - Self's prev_id will point to its predessor, nil if head
    #   - Self's next_id will be set to the rule that follows it, nil if tail
    #   - Self's prev_id and next_id will be updated in the database
    #   - Self's prev_id and next_id will be the only fields updated
    #   - The link will happen transactionally
    def link()
      ActiveRecord::Base.transaction do
        curr_rule = BudgetDB::Rule.find_by_id(self.id)
        raise ActiveRecord::RecordNotFound if nil == curr_rule
         # Ensure unlinked rule is not mistaken as head or tail
        curr_rule.prev_id = curr_rule.id
        curr_rule.next_id = curr_rule.id
        curr_rule.save
        if 1 == BudgetDB::Rule.count # Only rule in db
          self.prev_id = nil
          self.next_id = nil
        elsif nil == self.prev_id # prepend to ordered list
          first_rule = BudgetDB::Rule.find_by_prev_id(nil)
          raise ActiveRecord::RecordNotFound if nil == first_rule
          first_rule.prev_id = self.id
          self.next_id = first_rule.id
          first_rule.save
        else
          prev_rule = BudgetDB::Rule.find_by_id(self.prev_id)
          raise ActiveRecord::RecordNotFound if nil == prev_rule
          if(prev_rule.next)
            prev_rule.next.prev_id = self.id
            prev_rule.next.save
          end
          self.next_id = prev_rule.next_id
          prev_rule.next_id = self.id
          prev_rule.save
        end
        curr_rule.prev_id = self.prev_id
        curr_rule.next_id = self.next_id
        curr_rule.save
      end
    end

    # Applies the rule to the transactions in the database
    #
    # Requires:
    #   - The existence of a valid database connection
    #   - At least one action and one condition
    # Guarantees:
    #   - Records that match the condition(s) will be updated by the action(s)
    def apply()
      check_constraints
      where = Array.new
      set   = Array.new
      where.push conditions.map{|c| c.key+" "+c.op+" ?"}.join(" and ")
      where += conditions.map{|c| c.value}
      set.push actions.map{|c| c.key + " = ?"}.join(", ")
      set += actions.map{|c| c.value}
      BudgetDB::Transaction.update_all set, where
    end

    private

    def check_constraints()
      e0 = Exception.new("Rule should have at least one condition")
      e1 = Exception.new("Rule should have at least one action")
      e2 = Exception.new("Only one rule can have a NULL prev")
      e3 = Exception.new("Only one rule can have a NULL next")
      raise e0 if 0 >= conditions.length
      raise e1 if 0 >= actions.length
      if 0 < BudgetDB::Rule.count
        raise e2 if 1 != BudgetDB::Rule.find_all_by_prev_id(nil).length
        raise e3 if 1 != BudgetDB::Rule.find_all_by_next_id(nil).length
      end
    end
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
    # Load all of the rules (in order) from the database
    def load()
      rules = Array.new
      ex = Exception.new("Rules should have at least 1 condition and 1 action")
      first = BudgetDB::Rule.find_by_prev_id(nil)
      id = first ? first.id : nil
      while nil != id
        rule = BudgetDB::Rule.find_by_id(id)
        raise ActiveRecord::RecordNotFound if nil == rule
        raise ex if 0 >= rule.conditions.length || 0 >= rule.actions.length
        rules.push(rule)
        id = rule.next
      end
      return rules
    end

    # Commits each rule to the database
    #
    # Requires:
    #   - Rule was created by a previous call to new_rule
    # Guarantees:
    #   - The rule (including conditions and actions) will be updated in the db
    def save(rules)
    end

    # Applies the rules to the transactions in the database
    #
    # Requires:
    #   - Rules contain at least one action and one condition
    # Guarantees:
    #   - Records that match the condition(s) will be updated by the action(s)
    def apply(rules)
      rules.map{|r| r.apply}
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
      return @records.length
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
