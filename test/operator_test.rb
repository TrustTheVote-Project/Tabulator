#!/usr/bin/ruby

# OSDV Tabulator - TTV Tabulator Operator Unit Tests
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

# The Original Code is: TTV Tabulator
# The Initial Developer of the Original Code is Open Source Digital Voting Foundation.
# Portions created by Open Source Digital Voting Foundation are Copyright (C) 2010, 2011.
# All Rights Reserved.

# Contributors: Jeff Cook

require "yaml"
require "test/unit"
require "operator"

# The OperatorTest class provides Unit Testing for the Tabulator Operator.
# Tests are provided for all three types of errors detected by the Operator:
# Command errors, File errors, and Fatal errors.

class TabulatorOperatorTest < Test::Unit::TestCase

  TABULATOR_DATA_FILE = "TABULATOR_DATA.yml"

# Tests each of the Command errors detected by the Operator:
# * Command ... has no arguments
# * Command ... has 2 arguments (file names)
# * Command ... has 1 argument (file name)
# * Command ... has 1 optional argument (file name)
# * Command ... not recognized
# * Command ... ignored, Tabulator state: EMPTY
# * Command ... ignored, Tabulator state: not EMPTY

  def test_operator_command_errors
    optest_command_ok("reset")
    optest_command_error("foo")
    optest_command_error("foo blah blah")
    optest_command_error("reset blah blah")
    optest_command_error("data blah blah")
    optest_command_error("state blah blah")
    optest_command_error("total blah blah")
    optest_command_error("help blah blah")
    optest_command_error("load")
    optest_command_error("load blah")
    optest_command_error("load blah OK blah")
    optest_command_error("add")
    optest_command_error("add blah blah")
    optest_command_error("check blah blah")
    optest_command_error("data")
    optest_command_error("state")
    optest_command_error("total")
    optest_command_error("check")
    optest_command_ok("reset")
    optest_command_error("add data/Tests/Default/JD.yml")
    optest_command_ok("load data/Tests/Default/JD.yml data/Tests/Default/ED.yml OK")
    optest_command_ok("check")
    optest_command_error("load data/Tests/Default/JD.yml data/Tests/Default/ED.yml OK")
  end

# Tests each of the File errors detected by the Operator:
# * File non-existent ...
# * File open error ...
# * File read error ...
# * File contents error, not a Hash ...
# * File contents error, improper Hash, Key (...) missing ...
# * File syntax error ...

  def test_operator_file_errors
    optest_command_ok("reset")
    optest_command_ok("load data/Tests/Default/JD.yml data/Tests/Default/ED.yml OK")
    optest_file_error("add data/Tests/Default/CC0.yml")
    File.chmod(0222,"data/Tests/Validation/CC3_Write_Only.yml")
    optest_file_error("add data/Tests/Validation/CC3_Write_Only.yml")
    File.chmod(0644,"data/Tests/Validation/CC3_Write_Only.yml")
    optest_file_error("add tabulator.rb")
    optest_file_error("add data/Tests/Default/ED.yml")
    optest_file_error("add data/Tests/Validation/ARRAY.yml")
    optest_file_error("add data/Tests/Validation/CC2_Syntax_Error.yml")
  end

# Tests one (yes, only one) of the Fatal errors detected by the Operator:
# * Fatal failure of File.open (for read): TABULATOR_DATA.yml
# Fatal errors are hard to test, because they involve anomalous situations
# that should never occur, and hopefully they are equally hard to produce.  To
# test the error we cheat by changing the mode of the Tabulator dataset file
# to write-only, then try to read from it (generating the Fatal error), then
# we change it back, and try again to make sure it is OK.

  def test_operator_fatal_errors
    optest_command_ok("reset")
    optest_command_ok("load data/Tests/Default/JD.yml data/Tests/Default/ED.yml OK")
    optest_command_ok("check")
    File.chmod(0222, TABULATOR_DATA_FILE)
    optest_fatal_error("state")
    File.chmod(0644, TABULATOR_DATA_FILE)
    optest_command_ok("state")
  end

# Arguments:
# * <i>line</i>: (<i>String</i>) command line string
# 
# Returns: N/A
#
# Execute an Operator command, asserting that it will be error-free.

  private
  def optest_command_ok(line)
    print "\nTesting Operator Command: #{line}\n"
    args = line.split(/ /)
    result = TabulatorOperator.new.operator_command(args)
    assert((result == ""), "Expected no errors: #{result}")
  end

# Arguments:
# * <i>line</i>: (<i>String</i>) command line string
# 
# Returns: N/A
#
# Execute an Operator command, asserting that it will produce a Command error.

  def optest_command_error(line)
    print "\nTesting Operator Command Error: #{line}\n"
    args = line.split(/ /)
    result = TabulatorOperator.new.operator_command(args)
    assert((result =~ /^Command*/), "Expected Command error: #{result}")
  end

# Arguments:
# * <i>line</i>: (<i>String</i>) command line string
# 
# Returns: N/A
#
# Execute an Operator command, asserting that it will produce a File error.

  def optest_file_error(line)
    print "\nTesting Operator File Error: #{line}\n"
    args = line.split(/ /)
    result = TabulatorOperator.new.operator_command(args)
    assert((result =~ /^File*/), "Expected File error: #{result}")
  end

# Arguments:
# * <i>line</i>: (<i>String</i>) command line string
# 
# Returns: N/A
#
# Execute an Operator command, asserting that it will produce a Fatal error.

  def optest_fatal_error(line)
    print "\nTesting Operator Fatal Error: #{line}\n"
    args = line.split(/ /)
    result = TabulatorOperator.new.operator_command(args)
    assert((result =~ /^Fatal*/), "Expected Fatal error: #{result}")
  end

end
