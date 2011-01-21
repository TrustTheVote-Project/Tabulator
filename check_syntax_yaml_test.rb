# OSDV Tabulator - YAML Syntax Checker Unit Tests
# Author: Jeff Cook
# Date: 1/20/2011
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
require "check_syntax_yaml"
require "test/unit"

class CheckSyntaxYamlTest < Test::Unit::TestCase

# setup
#
# Define schemas for all known TTV CDF dataset types recognized by the Tabulator.  Call
# schema_process to validate each significant schema and then optionally write the schema
# to a file for later use by the Tabulator, for syntax-checking CDF datasets.  The
# schemas processed are:
# * unknown_type: invalid schema for testing schemas containing an unknown type
# * unknown_string: invalid schema for testing schemas containing an unrecognized string
# * invalid_hash_key: invalid schema for testing non-String schema Hash key
# * test_opt: schema for testing OPT(ional) Hash keys
# * test_alt: schema for testing ALT(ernate) Hash keys
# * district_info: District information schema
# * precinct_info: Precinct information schema
# * precount_info: Precount information schema
# * contest_info: Contest information schema
# * candidate_info: Candidate information schema
# * question_info: Question information schema
# * counter_info: Counter information schema
# * election_definition: Election Definition schema
# * answer_count: Answer Count schema
# * question_count: Question Count schema
# * candidate_count: Candidate Count schema
# * contest_count: Contest Count schema
# * audit_trail: Audit Trail schema
# * counter_count: Counter Count schema
# * tabulator_count: Tabulator Count schema
#
# The following schemas are defined but not processed, because they are subsumed by a
# higher-level schema: 
# * election_definition_info: Election Definition information schema, subsumed by Election Definition schema 
# * audit_trail_info: Audit Trail information schema, subsumed by Audit Trail schema
#
# NOTE from JVC: I don't know if it is appropriate to put the schema File generation process
# inside of this testing facility.

  def setup
    print "SETUP Started.\n"
    schema_unknown_type = {"unknown_type"=>100}
    schema_unknown_string = {"unknown_string"=>"Foobar"}
    schema_invalid_hash_key = {100=>"Foobar"}
    schema_test_opt = {"test_opt"=>"String", "|OPT|"=>{"foo"=>"Integer"}}
    schema_test_alt = {"test_alt"=>"String", "|ALT|"=>{"foo"=>"Date", "bar"=>"Date"}}
    schema_district_info = {"ident"=>"Atomic"}
    schema_precinct_info = {"ident"=>"Atomic"}
    schema_precount_info =
      {"ident"=>"Atomic",
      "district_ident_list"=>["Atomic"],
      "expected_count_list"=>[{"counter_ident"=>"Atomic", "count"=>"Integer"}]}
    schema_contest_info =
      {"ident"=>"Atomic",
      "district_ident"=>"Atomic"}
    schema_candidate_info =
      {"ident"=>"Atomic",
      "contest_ident"=>"Atomic"}
    schema_question_info =
      {"ident"=>"Atomic",
      "district_ident"=>"Atomic",
      "question"=>"String",
      "answer_list"=>["String"]}
    schema_counter_info = {"ident"=>"Atomic"}
    schema_election_definition_info =
      {"election"=>{"ident"=>"Atomic"},
      "jurisdiction"=>{"ident"=>"Atomic"},
      "district_list"=>[schema_district_info],
      "precinct_list"=>[schema_precinct_info],
      "precount_list"=>[schema_precount_info],
      "contest_list"=>[schema_contest_info],
      "candidate_list"=>[schema_candidate_info],
      "question_list"=>[schema_question_info],
      "counter_list"=>[schema_counter_info]}
    schema_election_definition =
      {"election_definition"=>schema_election_definition_info}
    schema_candidate_count = {"candidate_ident"=>"Atomic","count"=>"Integer"}
    schema_contest_count =
      {"contest_ident"=>"Atomic",
      "undervote_count"=>"Integer",
      "overvote_count"=>"Integer",
      "|OPT|"=>{"writein_count","Integer"},
      "candidate_count_list"=>[schema_candidate_count]}
    schema_answer_count = {"answer"=>"String", "count"=>"Integer"}
    schema_question_count =
      {"question_ident"=>"Atomic",
      "undervote_count"=>"Integer",
      "overvote_count"=>"Integer",
      "answer_count_list"=>[schema_answer_count]}
    schema_audit_trail_info =
      {"file_ident"=>"Atomic",
      "create_date"=>"Date",
      "operator"=>"String",
      "software"=>"String",
      "|OPT1|"=>{"hardware"=>"String"},
      "|OPT2|"=>{"provenance"=>["String"]}}
    schema_audit_trail = {"audit_trail"=>schema_audit_trail_info}
    schema_counter_count =
      {"counter_count"=>
      {"audit_trail"=>schema_audit_trail_info,
        "election_ident"=>"Atomic",
        "jurisdiction_ident"=>"Atomic",
        "precinct_ident"=>"Atomic",
        "reporting_group"=>"String",
        "counter_ident"=>"Atomic",
        "cast_ballot_count"=>"Integer",
        "contest_count_list"=>[schema_contest_count],
        "question_count_list"=>[schema_question_count]}}
    schema_tabulator_count =
      {"tabulator_count"=>
      {"audit_trail"=>schema_audit_trail_info,
        "election_ident"=>"Atomic",
        "jurisdiction_ident"=>"Atomic",
        "election_definition"=>schema_election_definition_info,
        "counter_count_list"=>[schema_counter_count],
        "contest_count_list"=>[schema_contest_count],
        "question_count_list"=>[schema_question_count]}}
    print "Schemas Defined.\n"    
    schema_setup("unknown_type", schema_unknown_type, false)
    schema_setup("unknown_string", schema_unknown_string, false)
    schema_setup("invalid_hash_key", schema_invalid_hash_key, false)
    schema_setup("test_opt", schema_test_opt)
    schema_setup("test_alt", schema_test_alt)
    schema_setup("district_info", schema_district_info)
    schema_setup("precinct_info", schema_precinct_info)
    schema_setup("precount_info", schema_precount_info)
    schema_setup("contest_info", schema_contest_info)
    schema_setup("candidate_info", schema_candidate_info)
    schema_setup("question_info", schema_question_info)
    schema_setup("counter_info", schema_counter_info)
    schema_setup("election_definition", schema_election_definition)
    schema_setup("answer_count", schema_answer_count)
    schema_setup("question_count", schema_question_count)
    schema_setup("candidate_count", schema_candidate_count)
    schema_setup("contest_count", schema_contest_count)
    schema_setup("audit_trail", schema_audit_trail)
    schema_setup("counter_count", schema_counter_count)
    schema_setup("tabulator_count", schema_tabulator_count)
    print "Schemas OK.\n"
    print "SETUP Done.\n\n"
  end  
  
# test_syntax_errors
#
# Test for syntax checker errors, by asserting the success of repeated calls
# to schema_check_syntax_error, each of which tests for a different syntax
# error code, and where all possible error codes are covered.

  def test_syntax_errors
    assert schema_check_syntax_error("unknown_type", true, 0)
    assert schema_check_syntax_error("unknown_string", true, 1)
    assert schema_check_syntax_error("question_info", false, 2)
    assert schema_check_syntax_error("test_opt", false, 3)
    assert schema_check_syntax_error("test_alt", false, 4)
    assert schema_check_syntax_error("district_info", false, 5)
    assert schema_check_syntax_error("precount_info", false, 6)
    assert schema_check_syntax_error("audit_trail", false, 7)
    assert schema_check_syntax_error("question_info", false, 2, 8)
    assert schema_check_syntax_error("invalid_hash_key", true, 9)
    assert schema_check_syntax_error("contest_info", false, 10)
    assert schema_check_syntax_error("test_opt", false, 3, 11)
    assert schema_check_syntax_error("test_opt", false, 3, 11, 12)
    assert schema_check_syntax_error("test_alt", false, 13)
    assert schema_check_syntax_error("test_alt", false, 4, 11, 14)
    assert schema_check_syntax_error("test_alt", false, 15)
  end

# test_syntax_schemas
#
# Test the syntax of all significant schemas, by asserting the success of
# repeated calls to schema_check_syntax, each of which uses data stored in
# files under Tests/Syntax to syntax-check against a schema defined during
# setup.  Some schemas, especially those with optional Hash keys, have multiple
# test variations.

  def test_syntax_schemas
    assert schema_check_syntax("test_opt")
    assert schema_check_syntax("test_alt")
    assert schema_check_syntax("district_info")
    assert schema_check_syntax("precinct_info")
    assert schema_check_syntax("precount_info")
    assert schema_check_syntax("contest_info")
    assert schema_check_syntax("candidate_info")
    assert schema_check_syntax("question_info")
    assert schema_check_syntax("counter_info")
    assert schema_check_syntax("election_definition")
    assert schema_check_syntax("answer_count")
    assert schema_check_syntax("question_count")
    assert schema_check_syntax("candidate_count")
    assert schema_check_syntax("contest_count")
    assert schema_check_syntax("audit_trail")
    assert schema_check_syntax("audit_trail", "_hardware")
    assert schema_check_syntax("audit_trail", "_provenance")
    assert schema_check_syntax("audit_trail", "_nil_provenance")
    assert schema_check_syntax("audit_trail", "_all")
    assert schema_check_syntax("counter_count")
    assert schema_check_syntax("tabulator_count")
  end
  
# schema_setup
#
# * <i>prefix</i>: [type String] prefix of the schema file name
# * <i>schema</i>: [type Arbitrary] schema to be written to a schema file
# * <i>check</i>:  [type Boolean] indicates when to check the validity of the schema (optional)
# * <i>write</i>:  [type Boolean] indicates when to over-write the schema file (optional)
#
# Returns: N/A
#
# Check the validity of the <i>schema</i>, unless <i>check</i> is <i>false</i> (for
# testing syntax errors involving invalid schemas), and raise an Exception if the validity
# check fails.  Schemas are stored in the Schemas/ subdirectory and are named
# "schema_foo.yml" when the schema is for an object named "foo".  If the schema file does
# not yet exist, it is written.  If it does exist, but the <i>write</i> flag is
# <i>true</i>, then it is over-written.  Deleting schema files allows them to be
# re-generated when these unit tests are run.

  private
  def schema_setup(prefix, schema, check = true, write = false)
    if (check)
      print "Checking Validity of Schema: #{prefix}\n"
      unless CheckSyntaxYaml.new.schema_is_valid?(schema)
        print "\n** ERROR** Invalid Schema: #{schema.inspect}\n\n"
        raise Exception
      end
    end
    file = "Schemas/" + prefix + "_schema.yml"
    if (! File.exist?(file))
      print "Writing Schema File: #{file}\n"
      File.open(file, "w") { |outfile| YAML::dump(schema, outfile) }
    elsif (write)
      print "Overwriting Schema File: #{file}\n"
      File.open(file, "w") { |outfile| YAML::dump(schema, outfile) }
    end
  end

# schema_check_syntax
#
# * <i>prefix</i>: [type String] prefix of the schema and data file names
# * <i>extra</i>:  [type String] part of the postfix of the data file name (optional)
#
# Returns: Boolean
#
# Read a schema from one file (under Schemas/) and a datum from another file (under
# Tests/Syntax/), and then return the result of performing a syntax check of the datum
# against the schema. 

  def schema_check_syntax(prefix, extra = '')
    file = "Schemas/" + "#{prefix}_schema.yml"
    print "Reading Schema File: #{file}\n"
    schema = File.open(file) { |infile| YAML::load(infile) }
    file = "Tests/Syntax/" + "#{prefix}" + extra + ".yml"
    print "Reading Data File: #{file}\n"
    datum = File.open(file) { |infile| YAML::load(infile) }
    cs = CheckSyntaxYaml.new
    if (! cs.check_syntax(schema, datum))
      print "\n** ERROR ** The previous syntax check test MUST NOT fail\n\n"
      return false
    else
      print "Check Syntax of #{prefix}: OK\n\n"
      return true
    end
  end
  
# schema_check_syntax_error
#
# * <i>prefix</i>: [type String] prefix of the schema and data file names
# * <i>noval</i>:  [type Boolean] indicates when the schema is NOT to be validated
# * <i>err1</i>:   [type Integer] error code 1
# * <i>err2</i>:   [type Integer] error code 2 (optional)
# * <i>err3</i>:   [type Integer] error code 3 (optional)
#
# Returns: Boolean
#
# Read a schema from one file (under Schemas/) and a datum containing a syntax error from
# another file (under Tests/Syntax/Errors/), and then perform a syntax check of the datum
# against the schema.  If <i>noval</i> is <i>true</i>, the schema validation check is
# bypassed during the syntax check.  We are testing for errors, so the syntax check must
# fail, and the error code stack's first three errors should be <i>err1</i>, <i>err2</i>
# (optional), and <i>err3</i> (optional).  Return <i>true</i> if and only if the syntax
# check fails and generates the expected errors.

  def schema_check_syntax_error(prefix, noval, err1, err2 = '', err3 = '')
    file = "Schemas/" + "#{prefix}_schema.yml"
    print "Reading Schema File: #{file}\n"
    schema = File.open(file) { |infile| YAML::load(infile) }

    file = "Tests/Syntax/Errors/" + "#{prefix}_" + err1.inspect + ".yml"
    print "Reading Data Error File: #{file}\n"
    datum = File.open(file) { |infile| YAML::load(infile) }

    cs = CheckSyntaxYaml.new
    if (noval ? cs.check_syntax_test(schema, datum) : cs.check_syntax(schema, datum))
      print "\n** ERROR ** The previous syntax check test MUST fail\n"
      return false
    end
    if ((err3 != '') && (err3 != cs.error_stack[2]))
      print "\n** ERROR ** 3rd error code (#{cs.error_stack[2].inspect}) must be: #{err3}\n\n"
      return false
    end
    if ((err2 != '') && (err2 != cs.error_stack[1]))
      print "\n** ERROR ** 2nd error code (#{cs.error_stack[1].inspect}) must be: #{err2}\n\n"
      return false
    end
    if (err1 != cs.error_stack[0])
      print "\n** ERROR ** 1st error code (#{cs.error_stack[0].inspect}) must be: #{err1}\n\n"
      return false
    end
    print "Check Syntax of #{prefix}: OK\n\n"
    return true
  end
  
end
