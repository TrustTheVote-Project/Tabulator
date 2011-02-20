#!/usr/bin/ruby

# OSDV Tabulator - TTV Tabulator Unit Tests
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
require "lib/syntax_checker"
require "lib/tabulator"

# The TabulatorTest class provides Unit Testing for the Tabulator class.  It
# does not test for errors, but for achievement of state and correct vote
# counts.

class TabulatorTest < Test::Unit::TestCase

  TABULATOR_DATA_FILE = "TABULATOR_DATA.yml"
  ERRHEAD = "** ERROR **"
  WARHEAD = "** WARNING **"
  
# Tests for successful DONE state achievement and specified number of missing
# counts, test data from data/Tests/Validation.

  def test_tabulator
    trace = 300          # In case we need to trace, for debugging these tests
    dir = "data/Tests/Validation"
    tabtest_tabulator_new(trace, dir, "JD.yml", "ED.yml")
    tabtest_add_counter_count(trace, dir, "CC1.yml", 2)
    tabtest_add_counter_count(trace, dir, "CC2.yml", 1)
    tabtest_add_counter_count(trace, dir, "CC3.yml", true)
  end

# Tests for successful DONE state achievement, specified number of missing
# counts, and exact voting results for three Counter Counts; test data from
# data/Tests/Default.

  def test_tabulator_default
    trace = 300
    dir = "data/Tests/Default"
    tabtest_tabulator_new(trace, dir, "JD.yml", "ED.yml")
    cvotes = {"CONTEST_1"=>
      {"undervote_count"=>0,"overvote_count"=>0,"writein_count"=>1,
        "candidates"=>{"CANDIDATE_1"=>5,"CANDIDATE_2"=>10}},
      "CONTEST_3"=>
      {"undervote_count"=>0,"overvote_count"=>1,"writein_count"=>0,
        "candidates"=>{"CANDIDATE_3"=>15}}}
    qvotes = {"QUESTION_2"=>
      {"undervote_count"=>1,"overvote_count"=>0,
        "answers"=>{"A"=>20,"B"=>25,"C"=>30}}}
    tabtest_add_counter_count(trace, dir, "CC1.yml", 2, cvotes, qvotes)
    cvotes = {"CONTEST_1"=>
      {"undervote_count"=>0,"overvote_count"=>1,"writein_count"=>1,
        "candidates"=>{"CANDIDATE_1"=>35,"CANDIDATE_2"=>35}},
      "CONTEST_3"=>
      {"undervote_count"=>1,"overvote_count"=>1,"writein_count"=>0,
        "candidates"=>{"CANDIDATE_3"=>35}}}
    qvotes = {"QUESTION_2"=>
      {"undervote_count"=>1,"overvote_count"=>1,
        "answers"=>{"A"=>35,"B"=>35,"C"=>35}}}
    tabtest_add_counter_count(trace, dir, "CC2.yml", 1, cvotes, qvotes)
    cvotes = {"CONTEST_1"=>
      {"undervote_count"=>3,"overvote_count"=>3,"writein_count"=>3,
        "candidates"=>{"CANDIDATE_1"=>50,"CANDIDATE_2"=>50}},
      "CONTEST_3"=>
      {"undervote_count"=>3,"overvote_count"=>3,"writein_count"=>3,
        "candidates"=>{"CANDIDATE_3"=>50}}}
    qvotes = {"QUESTION_2"=>
      {"undervote_count"=>3,"overvote_count"=>3,
        "answers"=>{"A"=>50,"B"=>50,"C"=>50}}}
    tabtest_add_counter_count(trace, dir, "CC3.yml", true, cvotes, qvotes)
  end

# Tests for specified number of missing counts, test data from
# data/Test/Bedrock.

  def test_tabulator_bedrock
    trace = 300
    dir = "data/Tests/Bedrock"
    tabtest_tabulator_new(trace, dir, "Bedrock_JD.yml", "Bedrock_ED.yml")
    tabtest_add_counter_count(trace, dir, "Bedrock_CC1.yml", 4)
  end

# Arguments:
# * <i>trace</i>:  (<i>Integer</i>) limits tracing of output for the syntax checker
# * <i>prefix</i>: (<i>String</i>) prefix of the schema file name
# * <i>file</i>:   (<i>String</i>) Tabulator data file name
#
# Returns: <i>Hash</i>
#
# Read a schema from one file (under data/Schemas/) and a datum from another
# file from <i>dir</i>/, and then tests the success of performing a syntax
# check of the datum against the schema.

  private
  def tabtest_check_syntax(trace, prefix, dir, file)
    schema_file = "data/Schemas/" + "#{prefix}_schema.yml"
    schema = tabtest_file_read(schema_file, "Schema")
    file = "#{dir}/#{file}"
    datum = tabtest_file_read(file, "Data")
    scy = SyntaxCheckerYaml.new
    errors, messages = scy.check_syntax(schema, datum, true, trace)
    print messages unless errors.length == 0
    assert(errors.length == 0, "Check Syntax of #{file} FAILED")
    print "Check Syntax of #{file}: OK\n"
    datum
  end

# Arguments:
# * <i>trace</i>:    (<i>Integer</i>) limits tracing of output for the syntax checker
# * <i>jd_file</i>:  (<i>String</i>) name of file holding Jurisdiction Definition
# * <i>ed_file</i>:  (<i>String</i>) name of file holding Election Definition
#
# Returns: N/A
#
# Tests the creation of a new Tabulator from a Jurisdiction Definition and an
# Election Definition.  No errors oir warnings should occur.

  def tabtest_tabulator_new(trace, dir, jd_file, ed_file)
    print "\nGenerating Initial Tabulator Count from Files: #{jd_file} #{ed_file}\n"
    jd = tabtest_check_syntax(trace, "jurisdiction_definition", dir, jd_file)
    ed = tabtest_check_syntax(trace, "election_definition", dir, ed_file)
    tab = Tabulator.new(jd, ed, TABULATOR_DATA_FILE)
    tc = tab.tabulator_count
    assert((tab.validation_errors.length == 0 &&
            tab.validation_warnings.length == 0),
           "Should be no errors or warnings.")
    tabtest_file_write_tabulator(tc)
    print "Initial Tabulator Count"
  end

# Arguments:
# * <i>messages</i>: (<i>Array</i>) of error/warning messages
# * <i>header</i>: (<i>Array</i>) of error/warning messages
# * <i>printit</i>: (<i>Boolean</i>) whether to print the error/warning messages (optional)
#
# Returns: <i>String</i>
#
# Returns a <i>String</i> containing the concatenation of all of the
# error/warning <i>messages</i>, each preceded by the <i>header</i> and
# followed by a <i>newline</i> character.  If <i>printit</i> is <i>true</i>,
# the <i>messages</i> are printed before being returned.

  def tabtest_print_messages(messages, header, printit = false)
    message = ""
    messages.each { |text| message += "#{header} #{text}\n"}
    print message if printit
    message
  end

# Arguments:
# * <i>tab</i>: (<i>Tabulator</i>) Tabulator object
#
# Returns: N/A
#
# Prints all error and warning messages currently held by the Tabulator.

  def tabtest_print_errors_warnings(tab)
    unless (tab.validation_errors.length == 0 &&
            tab.validation_warnings.length == 0)
      print "\n" 
      tabtest_print_messages(tab.validation_errors, ERRHEAD, true)
      tabtest_print_messages(tab.validation_warnings, WARHEAD, true)
    end
  end

# Arguments:
# * <i>trace</i>:    (<i>Integer</i>) limits tracing of output for the syntax checker
# * <i>cc_file</i>:  (<i>String</i>) name of file holding Counter Count
# * <i>done</i>:     (<i>Boolean</i>) check for Tabulator DONE state afterwards (optional)
#
# Returns: N/A
#
# Tests the accumulation of a new Counter Count after instantiating the
# Tabulator.  The proper number of <i>errors</i> and <i>warnings</i> should
# appear, and they should match exactly, content-wise.

  def tabtest_add_counter_count(trace, dir, cc_file, done, cvotes = false,
                                qvotes = false)
    tab = tabtest_tabulator_instantiate(trace)
    print "\nTabulator Accumulating New Counter Count from File: #{cc_file}\n"
    cc = tabtest_check_syntax(trace, "counter_count", dir, cc_file)
    tab.validate_counter_count(cc)
    tab.update_tabulator_count(cc)
    assert((tab.validation_errors.length == 0 &&
            tab.validation_warnings.length == 0),
           "Should be no errors or warnings.")
    tabtest_file_write_tabulator(tab.tabulator_count)
    print "Counter Count ACCUMULATED\n"
    tabtest_print_errors_warnings(tab)
    doneness = tab.tabulator_state
    if (done == true)
      print "Checking to see if Tabulator State is DONE... "
      assert((doneness[0] =~ /^DONE/) && (doneness[1].length == 0),
             "Tabulator State should be DONE but is not:\n#{doneness[0]}\n")
      print "YES!\n"
    else
      print "Checking counts missing: #{done.to_s}\n"
      missing = doneness[1].length
      assert((missing == done),
             "There should be #{done.to_s} missing counts, not #{missing.to_s}")
    end
    tabtest_votes_contest(tab, cvotes) unless cvotes == false
    tabtest_votes_question(tab, qvotes) unless qvotes == false
  end
  
# Arguments:
# * <i>tab</i>: (<i>Tabulator</i>) Tabulator object
# * <i>cvotes</i>: (<i>Array</i>) Expected contest vote counts
#
# Returns: N/A
#
# Checks the correctness of the vote counts for contests.

  def tabtest_votes_contest(tab, cvotes)
    cvotes.keys.each do |conid|
      v1 = cvotes[conid]["undervote_count"]
      v2 = tab.counts_contests[conid]["undervote_count"]
      print "Checking overvote count (#{v1}) for contest #{conid}\n"
      assert(v1 == v2,
             "Contest #{conid} undervote error, expected #{v1} but got #{v2}")
      v1 = cvotes[conid]["overvote_count"]
      v2 = tab.counts_contests[conid]["overvote_count"]
      print "Checking undervote count (#{v1}) for contest #{conid}\n"
      assert(v1 == v2,
             "Contest #{conid} overvote error, expected #{v1} but got #{v2}")
      v1 = cvotes[conid]["writein_count"]
      v2 = tab.counts_contests[conid]["writein_count"]
      print "Checking write-in vote count (#{v1}) for contest #{conid}\n"
      assert(v1 == v2,
             "Contest #{conid} writein vote error, expected #{v1} but got #{v2}")
      cvotes[conid]["candidates"].each do |k, v|
        tabtest_vote_candidate(tab, conid, k, v)
      end
    end
  end

# Arguments:
# * <i>tab</i>: (<i>Tabulator</i>) Tabulator object
# * <i>conid</i>: (<i>String</i>) Contest UID
# * <i>k</i>: (<i>String</i>) Candidate UID
# * <i>v</i>: (<i>String</i>) Candidate vote count
#
# Returns: N/A
#
# Checks the correctness of the vote count of the candidate for the Contest.

  def tabtest_vote_candidate(tab, conid, k, v)
    tab.counts_contests[conid]["candidate_count_list"].each do |cc|
      if (cc["candidate_ident"] == k)
        v2 = cc["count"]
        print "Checking #{k} vote count (#{v}) for contest #{conid}\n"
        assert(v == v2,
               "Contest #{conid} Candidate #{k} vote error, expected #{v} but got #{v2}")
      end
    end
  end

# Arguments:
# * <i>tab</i>: (<i>Tabulator</i>) Tabulator object
# * <i>qvotes</i>: (<i>Array</i>) Expected question vote counts
#
# Returns: N/A
#
# Checks the correctness of the vote counts for questions.

  def tabtest_votes_question(tab, qvotes)
    qvotes.keys.each do |conid|
      v1 = qvotes[conid]["undervote_count"]
      v2 = tab.counts_questions[conid]["undervote_count"]
      print "Checking overvote count (#{v1}) for question #{conid}\n"
      assert(v1 == v2,
             "Question #{conid} undervote error, expected #{v1} but got #{v2}")
      v1 = qvotes[conid]["overvote_count"]
      v2 = tab.counts_questions[conid]["overvote_count"]
      print "Checking undervote count (#{v1}) for question #{conid}\n"
      assert(v1 == v2,
             "Question #{conid} overvote error, expected #{v1} but got #{v2}")
      qvotes[conid]["answers"].each do |k, v|
        tabtest_vote_answer(tab, conid, k, v)
      end
    end
  end

# Arguments:
# * <i>tab</i>: (<i>Tabulator</i>) Tabulator object
# * <i>qid</i>: (<i>String</i>) Question UID
# * <i>k</i>: (<i>String</i>) Answer UID
# * <i>v</i>: (<i>String</i>) Answer vote count
#
# Returns: N/A
#
# Checks the correctness of the vote count of the Answer to the Question.

  def tabtest_vote_answer(tab, qid, k, v)
    tab.counts_questions[qid]["answer_count_list"].each do |ac|
      if (ac["answer"] == k)
        v2 = ac["count"]
        print "Checking #{k} vote count (#{v}) for question #{qid}\n"
        assert(v == v2,
               "Question #{qid} Answer #{k} vote error, expected #{v} but got #{v2}")
      end
    end
  end


# Arguments:
# * <i>trace</i>:  (<i>Integer</i>) limits tracing of output for the syntax checker
#
# Returns: N/A
#
# Tests the instantiation of a new Tabulator from the contents of the
# <tt><b>TABULATOR_DATA_FILE</b></tt>. There should be no errors or warnings.

  def tabtest_tabulator_instantiate(trace)
    tc_file = TABULATOR_DATA_FILE
    print "\nInstantiating Tabulator from File: #{tc_file}\n"
    tc = tabtest_check_syntax(trace, "tabulator_count", ".", tc_file)
    tab = Tabulator.new(false, false, false, tc)
    taberrs = tab.validation_errors.length
    assert(0 == taberrs,
           "Expected NO Validation Errors, Received: #{taberrs.to_s}" +
           tabtest_print_messages(tab.validation_errors, ERRHEAD))
    tabwarns = tab.validation_warnings.length
    assert(0 == tabwarns,
           "Expected NO Validation Warnings, Received: #{tabwarns.to_s}" +
           tabtest_print_messages(tab.validation_warnings, WARHEAD))
    print "Tabulator Successfully Instantiated from File\n"
    tab
  end

# Arguments:
# * <i>file</i>: (<i>String</i>) file name
#
# Returns: N/A
#
# Reads and returns the contents of the <i>file</i>, while testing to ensure
# the file read operation succeeds.

  def tabtest_file_read(file, label)
    print "Reading #{label}: #{file}\n"
    assert(schema = File.open(file) { |infile| YAML::load(infile) },
           "Error Reading from #{label} File: #{file}")
    schema
  end

# Arguments:
# * <i>tc</i>: (<i>Hash</i>) Tabulator Count data
#
# Returns: N/A
#
# Writes the Tabulator Count data to the <tt><b>TABULATOR_DATA_FILE</b></tt>, while
# testing to ensure that the file write operation succeeds.

  def tabtest_file_write_tabulator(tc)
    file = TABULATOR_DATA_FILE
    print "Writing Tabulator Count: #{file}\n"
    assert(File.open(file, "w") { |outfile| YAML::dump(tc, outfile) },
           "Error Writing to File: #{file}")
  end

end
