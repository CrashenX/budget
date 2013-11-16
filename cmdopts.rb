#!/usr/bin/env ruby
# Command line options parsing library
# Copyright (C) 2013 Jesse J. Cook
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

require 'optparse'
require 'ostruct'
require 'pp'

class CmdOpts

  def self.parse(args)
    options = OpenStruct.new
    options.password = "password"
    options.insert   = false
    options.show     = false

    opts = OptionParser.new do |opts|
      opts.banner = "usage: budget.rb [options]"

      opts.on("-p", "--password PASSWORD",
              "Password used to access budget information") do |p|
          options.password = p
      end

      opts.on("-i", "--[no-]insert",
              "Insert a test value into the database") do |i|
          options.insert = i
      end

      opts.on("-s", "--[no-]show",
              "Shows count of all test values in the database") do |s|
          options.show = s
      end

    end

    # Calling OptionParser parse! method
    opts.parse!(args)
    options
  end
end

if __FILE__ == $0
  options = CmdOpts.parse(ARGV)
  pp options
end
