#!/usr/bin/ruby

# OSDV Tabulator - YAML Syntax Checker for TTV CDF Datasets
# Author: Jeff Cook
# Date: 2/2/2011
#
# License Version: OSDV Public License 1.2
#
# The contents of this file are subject to the OSDV Public License
# Version 1.2 (the "License"); you may not use this file except in
# compliance with the License. You may obtain a copy of the License at
# http://www.osdv.org/license/
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
# License for the specific language governing rights and limitations
# under the License.

# The Original Code is: TTV Tabulator.
# The Initial Developer of the Original Code is Open Source Digital Voting Foundation.
# Portions created by Open Source Digital Voting Foundation are Copyright (C) 2010, 2011.
# All Rights Reserved.

# Contributors: Jeff Cook

require "yaml"
require "test/unit"
require "operator"

# The OperatorTest class provides Unit Testing for the Operator class.

class OperatorTest < Test::Unit::TestCase

# Tests for all possible Command and File errors generated by the Operator

  def test_operator
    op = Operator.new()
    operator_command(op, "reset")
    operator_command_error(op,"foo")
    operator_command_error(op,"foo blah blah")
    operator_command_error(op,"reset blah blah")
    operator_command_error(op,"data blah blah")
    operator_command_error(op,"state blah blah")
    operator_command_error(op,"total blah blah")
    operator_command_error(op,"help blah blah")
    operator_command_error(op,"load")
    operator_command_error(op,"load blah")
    operator_command_error(op,"load blah OK blah")
    operator_command_error(op,"add")
    operator_command_error(op,"add blah blah")
    operator_command_error(op,"check blah blah")
    operator_command_error(op,"data")
    operator_command_error(op,"state")
    operator_command_error(op,"total")
    operator_command_error(op,"check")
    #operator_command(op, "load Tests/Default/JD.yml Tests/Default/ED.yml OK")
    #operator_command(op, "load Tests/Validation/JD.yml Tests/Validation/ED.yml OK")
    #operator_command(op, "check")

end

  private
  def operator_command(op, text)
    print "Testing Operator Command: #{text}\n"
    args = text.split(/ /)
    result = op.op_command(args)
    assert((result == ""), "Expected No Error, got: #{result}")
  end

  def operator_command_error(op, text)
    print "Testing Operator Command Error: #{text}\n"
    args = text.split(/ /)
    result = op.op_command(args)
    assert((result =~ /^Command*/), "Expected Command Error, got: #{result}")
  end

  def operator_file_error(op, text)
    print "Testing Operator File Error: #{text}\n"
    args = text.split(/ /)
    result = op.op_command(args)
    assert((result =~ /^File*/), "Expected File Error, got: #{result}")
  end

end
