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

# The OperatorTest class provides Unit Testing for the Tabulator Operator.

class OperatorTest < Test::Unit::TestCase

  TABULATOR_COUNT_FILE = "TABULATOR_COUNT.yml"

# Tests many different Operator error-handling situations.

  def test_operator
    operator_test_command_errors()
    operator_test_file_errors()
    operator_test_fatal_errors()
  end

# Tests all of the Command errors detected by the Operator.

  private
  def operator_test_command_errors
    operator_command("reset")
    operator_command_error("foo")
    operator_command_error("foo blah blah")
    operator_command_error("reset blah blah")
    operator_command_error("data blah blah")
    operator_command_error("state blah blah")
    operator_command_error("total blah blah")
    operator_command_error("help blah blah")
    operator_command_error("load")
    operator_command_error("load blah")
    operator_command_error("load blah OK blah")
    operator_command_error("add")
    operator_command_error("add blah blah")
    operator_command_error("check blah blah")
    operator_command_error("data")
    operator_command_error("state")
    operator_command_error("total")
    operator_command_error("check")
    operator_command("reset")
    operator_command_error("add Tests/Default/JD.yml")
    operator_command("load Tests/Default/JD.yml Tests/Default/ED.yml OK")
    operator_command("check")
    operator_command_error("load Tests/Default/JD.yml Tests/Default/ED.yml OK")
  end

# Tests all of the File errors detected by the Operator:
# * File non-existent ...
# * File open (for read) error ...
# * File read error ...
# * File contents error, not a Hash ...
# * File contents error, Hash Key (...) missing ...
# * File syntax error ...

  def operator_test_file_errors
    operator_command("reset")
    operator_command("load Tests/Default/JD.yml Tests/Default/ED.yml OK")
    operator_file_error("add Tests/Default/CC0.yml")
    File.chmod(0222,"Tests/Default/CC3_Write_Only.yml")
    operator_file_error("add Tests/Default/CC3_Write_Only.yml")
    File.chmod(0644,"Tests/Default/CC3_Write_Only.yml")
    operator_file_error("add tabulator.rb")
    operator_file_error("add Tests/Default/ED.yml")
    operator_file_error("add Tests/Default/ARRAY.yml")
    operator_file_error("add Tests/Default/CC2_Syntax_Error.yml")
  end

# Tests one (1) of the Fatal errors detected by the Operator.  These are hard
# to test, because they involve anomalous situations that should never occur,
# and hopefully they are equally hard to produce.  We cheat by changing the
# mode of the Tabulator dataset file to write-only, then try to read from it
# (generating the Fatal error), then we change it back.

  def operator_test_fatal_errors
    tc_file = "TABULATOR_COUNT.yml"
    operator_command("reset")
    operator_command("load Tests/Default/JD.yml Tests/Default/ED.yml OK")
    operator_command("check")
    File.chmod(0222, tc_file)
    operator_fatal_error("check")
    File.chmod(0644, tc_file)
    operator_command("check")
  end

# Arguments:
# * <i>line</i>: (<i>String</i>) command line as a single string
# 
# Returns: N/A
#
# Execute an Operator command, asserting that it will be error-free.

  def operator_command(line)
    print "\nTesting Operator Command: #{line}\n"
    args = line.split(/ /)
    result = Operator.new.op_command(args)
    assert((result == ""), "Expected no errors: #{result}")
  end

# Arguments:
# * <i>line</i>: (<i>String</i>) command line as a single string
# 
# Returns: N/A
#
# Execute an Operator command, asserting that it will produce a Command error.

  def operator_command_error(line)
    print "\nTesting Operator Command Error: #{line}\n"
    args = line.split(/ /)
    result = Operator.new.op_command(args)
    assert((result =~ /^Command*/), "Expected Command error: #{result}")
  end

# Arguments:
# * <i>line</i>: (<i>String</i>) command line as a single string
# 
# Returns: N/A
#
# Execute an Operator command, asserting that it will produce a File error.

  def operator_file_error(line)
    print "\nTesting Operator File Error: #{line}\n"
    args = line.split(/ /)
    result = Operator.new.op_command(args)
    assert((result =~ /^File*/), "Expected File error: #{result}")
  end

# Arguments:
# * <i>line</i>: (<i>String</i>) command line as a single string
# 
# Returns: N/A
#
# Execute an Operator command, asserting that it will produce a Fatal error.

  def operator_fatal_error(line)
    print "\nTesting Operator Fatal Error: #{line}\n"
    args = line.split(/ /)
    result = Operator.new.op_command(args)
    assert((result =~ /^Fatal*/), "Expected Fatal error: #{result}")
  end

end
