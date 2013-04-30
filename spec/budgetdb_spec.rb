#!/usr/bin/env ruby
# BudgetDB tests
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

describe BudgetDB::Rule do
  before :all do
    @db = BudgetDB.connect("rspec", "rspec", "budgettest")
    ActiveRecord::Base.connection.execute(IO.read("./budget.sql"))
  end
  before :each do
    @rule = BudgetDB::Rule.new
    @rule.conditions.push BudgetDB::Condition.new( :key   => 'amount'\
                                                 , :op    => '='\
                                                 , :value => '125.00'\
                                                 )
    @rule.actions.push BudgetDB::Action.new( :key   => 'display'\
                                           , :value => 'foo'\
                                           )
  end
  after :all do
    ActiveRecord::Base.connection.execute(IO.read("./drop.sql"))
  end
  describe "#link_and_save" do
    it "inserts a rule at the beginning of nil list for nil prev_id" do
      @rule.link_and_save
      @rule.reload
      @rule.prev.should eql nil
      @rule.next.should eql nil
    end
    it "inserts rule at the end of list when prev_id is last rule id" do
      last_rule = BudgetDB::Rule.find_by_next_id(nil)
      @rule.prev_id = last_rule.id
      @rule.link_and_save
      @rule.prev.reload
      last_rule.reload
      @rule.prev.should eql last_rule
      last_rule.next.should eql @rule
    end
    it "inserts rule after head when prev_id is head" do
      first_rule = BudgetDB::Rule.find_by_prev_id(nil)
      next_id = first_rule.next_id
      @rule.prev_id = first_rule.id
      @rule.link_and_save
      @rule.prev.reload
      @rule.next.reload
      first_rule.reload
      next_rule = BudgetDB::Rule.find_by_id(next_id)
      @rule.prev.should eql first_rule
      first_rule.next.should eql @rule
      @rule.next.should eql next_rule
      next_rule.prev.should eql @rule
    end
    it "inserts a rule at the beginning of list for nil prev_id" do
      first_rule = BudgetDB::Rule.find_by_prev_id(nil)
      @rule.link_and_save
      @rule.reload
      first_rule.reload
      @rule.next.should eql first_rule
      first_rule.prev.should eql @rule
    end
  end
end

describe BudgetDB::Records do
  # TODO: Add more robust tests that are not dependent on specific data set
  before :all do
    @db = BudgetDB.connect("rspec", "rspec", "budgettest")
    ActiveRecord::Base.connection.execute(IO.read("./budget.sql"))
    @records = BudgetDB::Records.new
  end
  after :all do
    ActiveRecord::Base.connection.execute(IO.read("./drop.sql"))
  end
  describe "#load" do
    it "loads statements, accounts, transactions, and budgets" do
      count = @records.load("budgetdb_spec.records")
      count.should eql 21
    end
    it "inserts loaded records into the database" do
      @records.save
      BudgetDB::Statement.all.length.should eql 2
      BudgetDB::Account.all.length.should eql 2
      BudgetDB::Transaction.all.length.should eql 8
      BudgetDB::Budget.all.length.should eql 9
    end
  end
end
