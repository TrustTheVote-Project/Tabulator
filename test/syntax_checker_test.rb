#!/usr/bin/ruby

# OSDV Tabulator - TTV Tabulator Syntax Checker (YAML) Unit Tests
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
require "test/unit"
require "lib/syntax_checker"

# The SyntaxCheckerYamlTest class provides Unit Testing for the SyntaxCheckerYaml
# class.  It also (re)initializes, during setup, the set of schemas used by
# the syntax checker, held in the directory data/Schemas.  If the contents of
# this directory are emptied, all schemas files are written anew.  If any
# schema file is missing from this directory, a new one is written to replace
# it.

class SyntaxCheckerYamlTest < Test::Unit::TestCase

# Change this constant to <i>true</i> if you want these tests to regenerate
# the built-in schema files each time the tests are run.  When <i>false</i>,
# new schema files are written only if they are missing from data/Schemas/.

  SCHEMA_OVERWRITE = false

# Define schemas for all known TTV CDF dataset types recognized by the
# Tabulator.  Calls schema_setup to validate each significant schema and then
# optionally write the schema to a file for later use by the Tabulator.  The
# following schemas are processed:  
# * unknown_type: for testing (invalid) schemas containing an unknown type
# * unknown_string: for testing (invalid) schemas containing an unrecognized string
# * invalid_hash_key: for testing (invalid) schema containing non-String Hash key
# * test_opt: for testing schemas with OPT(ional) Hash keys
# * test_alt: for testing schemas with ALT(ernate) Hash keys
# * district_info: District information schema
# * precinct_info: Precinct information schema
# * audit_header_info: Audit Header information schema
# * audit_header: Audit Header schema
# * jurisdiction_definition_info: Jurisdiction Definition information schema
# * jurisdiction_definition: Jurisdiction Definition schema
# * expected_count_info: Expected Count information schema
# * contest_info: Contest information schema
# * candidate_info: Candidate information schema
# * question_info: Question information schema
# * counter_info: Counter information schema
# * election: Election schema
# * election_definition_info: Election Definition information schema
# * election_definition: Election Definition schema
# * answer_count: Answer Count schema
# * question_count: Question Count schema
# * candidate_count: Candidate Count schema
# * contest_count: Contest Count schema
# * counter_count: Counter Count schema
# * tabulator_count: Tabulator Count schema
#
# The following schemas are defined but not processed, because they are
# subsumed by a higher-level schemas:
# * jurisdiction_definition_info: subsumed by Jurisdiction Definition schema
# * election_definition_info: subsumed by Election Definition schema
# * audit_header_info: subsumed by Audit Header schema

  def setup
    trace = 300
    schema_unknown_type = {"unknown_type"=>100}
    schema_unknown_string = {"unknown_string"=>"Foobar"}
    schema_invalid_hash_key = {100=>"Foobar"}
    schema_test_opt = {"test_opt"=>"String", "|OPT|"=>{"foo"=>"Integer"}}
    schema_test_alt =
      {"test_alt"=>"String","|ALT|"=>{"foo"=>"String", "bar"=>"String"}}
    schema_district_info = {"ident"=>"Atomic",
      "|OPT1|"=>{"display_name"=>"String"},
      "|OPT2|"=>{"type"=>"String"}}
    schema_precinct_info = {"ident"=>"Atomic",
      "|OPT|"=>{"display_name"=>"String"}}
    schema_audit_header_info =
      {"file_ident"=>"Atomic",
      "create_date"=>"String",
      "operator"=>"String",
      "software"=>"String",
      "|OPT1|"=>{"schema_version"=>"String"},
      "|OPT2|"=>{"type"=>"String"},
      "|OPT3|"=>{"hardware"=>"String"},
      "|OPT4|"=>{"provenance"=>["String"]}}
    schema_audit_header = {"audit_header"=>schema_audit_header_info}
    schema_jurisdiction_definition_info =
      {"ident"=>"Atomic",
      "district_list"=>[schema_district_info],
      "precinct_list"=>[schema_precinct_info],
      "audit_header"=>schema_audit_header_info,
      "|OPT1|"=>{"error_list"=>["String"]},
      "|OPT2|"=>{"warning_list"=>["String"]}}
    schema_jurisdiction_definition =
      {"jurisdiction_definition"=>schema_jurisdiction_definition_info}
    schema_expected_count_info =
      {"counter_ident"=>"Atomic",
      "precinct_ident_list"=>["Atomic"],
      "reporting_group"=>"String"}
    schema_contest_info =
      {"ident"=>"Atomic",
      "|OPT|"=>{"display_name"=>"String"},
      "district_ident"=>"Atomic"}
    schema_candidate_info =
      {"ident"=>"Atomic",
      "|OPT1|"=>{"display_name"=>"String"},
      "|OPT2|"=>{"party_display_name"=>"String"},
      "|OPT3|"=>{"position"=>"Integer"},
      "contest_ident"=>"Atomic"}
    schema_question_info =
      {"ident"=>"Atomic",
      "|OPT|"=>{"display_name"=>"String"},
      "district_ident"=>"Atomic",
      "question"=>"String",
      "answer_list"=>["String"]}
    schema_counter_info = {"ident"=>"Atomic",
      "|OPT|"=>{"display_name"=>"String"}}
    schema_election_info = {"ident"=>"Atomic",
      "|OPT1|"=>{"display_name"=>"String"},
      "|OPT2|"=>{"start_date"=>"String"},
      "|OPT3|"=>{"type"=>"String"}}
    schema_election_definition_info = 
      {"election"=>schema_election_info,
      "jurisdiction_ident"=>"Atomic",
      "contest_list"=>[schema_contest_info],
      "candidate_list"=>[schema_candidate_info],
      "question_list"=>[schema_question_info],
      "counter_list"=>[schema_counter_info],
      "reporting_group_list"=>["String"],
      "expected_count_list"=>[schema_expected_count_info],
      "audit_header"=>schema_audit_header_info,
      "|OPT1|"=>{"error_list"=>["String"]},
      "|OPT2|"=>{"warning_list"=>["String"]}}
    schema_election_definition =
      {"election_definition"=>schema_election_definition_info}
    schema_candidate_count = {"candidate_ident"=>"Atomic",
      "|OPT|"=>{"candidate_name"=>"String"},
      "count"=>"Integer"}
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
    schema_counter_count =
      {"counter_count"=>
      {"election_ident"=>"Atomic",
        "jurisdiction_ident"=>"Atomic",
        "counter_ident"=>"Atomic",
        "reporting_group"=>"String",
        "precinct_ident"=>"Atomic",
        "|OPT|"=>{"cast_ballot_count"=>"Integer"},
        "contest_count_list"=>[schema_contest_count],
        "question_count_list"=>[schema_question_count],
        "audit_header"=>schema_audit_header_info},
      "|OPT1|"=>{"error_list"=>["String"]},
      "|OPT2|"=>{"warning_list"=>["String"]}}
    schema_tabulator_count =
      {"tabulator_count"=>
      {"jurisdiction_ident"=>"Atomic",
        "election_ident"=>"Atomic",
        "jurisdiction_definition"=>schema_jurisdiction_definition_info,
        "election_definition"=>schema_election_definition_info,
        "contest_count_list"=>[schema_contest_count],
        "question_count_list"=>[schema_question_count],
        "counter_count_list"=>[schema_counter_count],
        "audit_header"=>schema_audit_header_info,
        "state"=>"String"}}
    schema_setup(trace, "unknown_type", schema_unknown_type, false)
    schema_setup(trace, "unknown_string", schema_unknown_string, false)
    schema_setup(trace, "invalid_hash_key", schema_invalid_hash_key, false)
    schema_setup(trace, "test_opt", schema_test_opt)
    schema_setup(trace, "test_alt", schema_test_alt)
    schema_setup(trace, "district_info", schema_district_info)
    schema_setup(trace, "precinct_info", schema_precinct_info)
    schema_setup(trace, "jurisdiction_definition",schema_jurisdiction_definition)
    schema_setup(trace, "expected_count_info", schema_expected_count_info)
    schema_setup(trace, "contest_info", schema_contest_info)
    schema_setup(trace, "candidate_info", schema_candidate_info)
    schema_setup(trace, "question_info", schema_question_info)
    schema_setup(trace, "counter_info", schema_counter_info)
    schema_setup(trace, "election_definition", schema_election_definition)
    schema_setup(trace, "answer_count", schema_answer_count)
    schema_setup(trace, "question_count", schema_question_count)
    schema_setup(trace, "candidate_count", schema_candidate_count)
    schema_setup(trace, "contest_count", schema_contest_count)
    schema_setup(trace, "audit_header", schema_audit_header)
    schema_setup(trace, "counter_count", schema_counter_count)
    schema_setup(trace, "tabulator_count", schema_tabulator_count)
    print "Schemas OK.\n\n"
  end  
  
# First test the errors generated by the syntax checker, by making repeated
# calls to syntax_ok_error, each of which tests for a different
# error code, and where all possible error codes are covered.
#
# Next test the syntax of data files representing all of the significant
# schemas, by making repeated calls to syntax_ok, each of which uses
# data stored in files under data/Tests/Syntax to syntax-check against a
# schema defined during setup.  Some schemas, especially those with optional
# Hash keys, have multiple test variations.

  def test_check_syntax
    trace = 300          # In case we need to trace, for debugging these tests
    syntax_error(trace, "unknown_type", false, 0)
    syntax_error(trace, "unknown_string", false, 1)
    syntax_error(trace, "question_info", true, 2)
    syntax_error(trace, "test_opt", true, 3)
    #syntax_error(trace, "test_alt", true, 4)
    syntax_error(trace, "district_info", true, 5)
    syntax_error(trace, "expected_count_info", true, 6)
    syntax_error(trace, "audit_header", true, 7)
    syntax_error(trace, "question_info", true, 2, 8)
    syntax_error(trace, "invalid_hash_key", false, 9)
    syntax_error(trace, "contest_info", true, 10)
    syntax_error(trace, "test_opt", true, 3, 11)
    syntax_error(trace, "test_opt", true, 3, 11, 12)
    syntax_error(trace, "test_alt", true, 13)
    syntax_error(trace, "test_alt", true, 2, 11, 14)
    syntax_error(trace, "test_alt", true, 15)
    syntax_ok(trace, "test_opt")
    syntax_ok(trace, "test_alt")
    syntax_ok(trace, "district_info")
    syntax_ok(trace, "precinct_info")
    syntax_ok(trace, "jurisdiction_definition")
    syntax_ok(trace, "expected_count_info")
    syntax_ok(trace, "contest_info")
    syntax_ok(trace, "candidate_info")
    syntax_ok(trace, "question_info")
    syntax_ok(trace, "counter_info")
    syntax_ok(trace, "election_definition")
    syntax_ok(trace, "answer_count")
    syntax_ok(trace, "question_count")
    syntax_ok(trace, "candidate_count")
    syntax_ok(trace, "contest_count")
    syntax_ok(trace, "audit_header")
    syntax_ok(trace, "audit_header", "_hardware")
    syntax_ok(trace, "audit_header", "_provenance")
    syntax_ok(trace, "audit_header", "_nil_provenance")
    syntax_ok(trace, "audit_header", "_all")
    syntax_ok(trace, "counter_count")
    syntax_ok(trace, "tabulator_count")
  end
  
# Arguments:
# * <i>trace</i>:    (<i>Integer</i>) limits tracing of output for the syntax checker
# * <i>prefix</i>:   (<i>String</i>) prefix of the schema file name
# * <i>schema</i>:   (<i>Arbitrary</i>) schema to be written to a schema file
# * <i>validate</i>: (<i>Boolean</i>) indicates when to check the validity of the schema (optional, default <i>true</i>)
#
# Returns: N/A
#
# Assert the validity of the <i>schema</i>, unless <i>validate</i> is
# <i>false</i>, in which case assert the invalidity of the <i>schema</i>.
# Schemas are stored in the data/Schemas/ subdirectory and are named
# "schema_foo.yml" when the schema is for an object named "foo".  If the
# schema file does not yet exist, it is written.  If it does exist, but the
# <i>write</i> flag is <i>true</i>, then it is over-written.  Deleting schema
# files from the data/Schemas/ directory permits these schemas to be
# re-generated when the unit tests are run.

  private
  def schema_setup(trace, prefix, schema, validate = true)
    if (validate)
      print "Checking Validity of Schema: #{prefix}\n"
      scy = SyntaxCheckerYaml.new
      result = scy.schema_is_valid?(schema, trace)
      assert(result, "Invalid schema: #{schema.inspect}")
      print scy.error_messages unless result
    else
      print "Checking Invalidity of Schema: #{prefix}\n"
      scy = SyntaxCheckerYaml.new
      result = scy.schema_is_valid?(schema, trace)
      assert(!result, "Valid schema (should be invalid): #{schema.inspect}")
      print scy.error_messages unless result
    end
    file = "data/Schemas/" + prefix + "_schema.yml"
    if (! File.exist?(file))
      print "Writing Schema File: #{file}\n"
      File.open(file, "w") { |outfile| YAML::dump(schema, outfile) }
    elsif (SCHEMA_OVERWRITE)
      print "Overwriting Schema File: #{file}\n"
      File.open(file, "w") { |outfile| YAML::dump(schema, outfile) }
    end
  end

# Arguments:
# * <i>trace</i>:   (<i>Integer</i>) limits tracing of output for the syntax checker
# * <i>prefix</i>:  (<i>String</i>) prefix of the schema and data file names
# * <i>postfix</i>: (<i>String</i>) postfix for the data file name (optional, default '')
#
# Returns: Boolean
#
# Read a schema from one file (under data/Schemas/) and a datum from another
# file (under data/Tests/Syntax/), and then assert the success of performing a
# syntax check of the datum against the schema.

  def syntax_ok(trace, prefix, postfix = '')
    file = "data/Schemas/" + "#{prefix}_schema.yml"
    print "Reading Schema File: #{file}\n"
    schema = File.open(file) { |infile| YAML::load(infile) }
    file = "data/Tests/Syntax/" + "#{prefix}" + postfix + ".yml"
    print "Reading Data File: #{file}\n"
    datum = File.open(file) { |infile| YAML::load(infile) }
    scy = SyntaxCheckerYaml.new
    errors, messages = scy.check_syntax(schema, datum, true, trace)
    print messages unless errors.length == 0
    assert(errors.length == 0, "Check Syntax of #{prefix} FAILED")
    print "Check Syntax of #{prefix}: OK\n\n"
  end
  
# Arguments:
# * <i>trace</i>:     (<i>Integer</i>) limits tracing of output for the syntax checker
# * <i>prefix</i>:    (<i>String</i>) prefix of the schema and data file names
# * <i>validate</i>:  (<i>Boolean</i>) indicates when the schema is to be validated
# * <i>err1</i>:      (<i>Integer</i>) error code 1
# * <i>err2</i>:      (<i>Integer</i>) error code 2 (optional, default -1)
# * <i>err3</i>:      (<i>Integer</i>) error code 3 (optional, default -1)
#
# Returns: Boolean
#
# Read a schema from one file (under data/Schemas/) and a datum containing a
# syntax error from another file (under data/Tests/Syntax/Errors/), and then
# assert the failure of performing a syntax check of the datum against the
# schema.  If <i>validate</i> is <i>false</i>, assert that the syntax checker
# will fail and the error code stack will contain -1 (schema validation
# error).  We are testing for errors, so the syntax check must fail, and the
# resulting error code stack's first three errors must be <i>err1</i>,
# <i>err2</i> (optional), and <i>err3</i> (optional).

  def syntax_error(trace, prefix, validate, err1, err2 = -1, err3 = -1)
    file = "data/Schemas/" + "#{prefix}_schema.yml"
    print "Reading Schema File: #{file}\n"
    schema = File.open(file) { |infile| YAML::load(infile) }
    file = "data/Tests/Syntax/Errors/" + "#{prefix}_" + err1.inspect + ".yml"
    print "Reading Data Error File: #{file}\n"
    datum = File.open(file) { |infile| YAML::load(infile) }
    scy = SyntaxCheckerYaml.new
    unless (validate)
      errors, messages = scy.check_syntax(schema, datum, true, trace)
      print messages unless errors.length == 0
      assert(errors.length > 0,
             "Check Syntax schema validation check of #{prefix}_schema did not FAIL, but SHOULD")
      assert((errors[0] == -1), "Check Syntax error code not: -1")
    end
    errors, messages = scy.check_syntax(schema, datum, validate, trace)
    print messages unless errors.length == 0
    assert(errors.length > 0,
           "Check Syntax of #{prefix} did not FAIL, but SHOULD")
    assert((err3 == errors[2]),
           "Check Syntax of #{prefix} 3rd error code should be: #{err3}") unless (err3 < 0)
    assert((err2 == errors[1]),
           "Check Syntax of #{prefix} 2nd error code should be: #{err2}") unless (err2 < 0)
    assert((err1 == errors[0]),
           "Check Syntax of #{prefix} 1st error code should be: #{err1}")
  end
  
end
