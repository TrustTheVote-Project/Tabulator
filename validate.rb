# OSDV Tabulator - YAML Syntax Checker for TTV CDF Datasets
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

# The TabulatorValidate class is used to validate the datasets that are
# imported into the Tabulator.  During the validation of either a Jurisdiction
# Definition or an Election Definition, it performs these additional
# operations:
# 1. Saves the names of all unique identifiers (UIDs)
# 2. Saves the Expected Counts information
# 3. Constructs and saves zero-initialized Contest Counts for each Contest
# 4. Constructs and saves zero-initialized Question Counts for each Question

class TabulatorValidate

# All of the election objects that can be given unique identifiers (UIDs).

  UID_TYPES = ["jurisdiction", "district", "precinct", "election",
               "reporting group", "contest", "candidate", "question",
               "counter", "file"]

# <i>Hash</i> with <i>Key</i>: from UID_TYPES, <i>Value</i>: <i>Array</i> of
# UIDs for that type; holds all the unique identifiers (UIDs), keyed by UID
# type

  attr_accessor :unique_ids

# <i>Hash</i> with <i>Key</i>: Contest UID, <i>Value</i>: Contest Count; holds
# all the Contest Counts, keyed by Contest UID

  attr_accessor :contest_counts

# <i>Hash</i> with <i>Key</i>: Question UID, <i>Value</i>: Question Count;
# holds all the Question Counts, keyed by Question UID

  attr_accessor :question_counts

# <i>Hash</i> with <i>Key</i>: Counter UID, <i>Value</i>: {<i>Hash</i> with
# <i>Key</i>: Reporting Group, <i>Value</i>: <i>Array</i> of Precinct UIDs};
# holds all the Expected Counts, keyed by Counter UID and then Reporting Group

  attr_accessor :expected_counts

# <i>Array</i>, stack of error messages

  attr_accessor :errors

# <i>Array</i>, stack of warning messages

  attr_accessor :warnings

# Initializes state by calling re_initialize.

  def initialize 
    re_initialize
  end

# No Arguments
# 
# Returns: N/A
#
# (Re)Initializes the state of all attributes, each set to empty for its
# particular type (zero for Integers).

  private
  def re_initialize
    self.unique_ids = Hash.new { |h,k| h[k] = [] }
    self.contest_counts = Hash.new { |h,k| h[k] = {} }
    self.question_counts = Hash.new { |h,k| h[k] = {} }
    self.expected_counts = Hash.new { |h,k| h[k] = [] }
    errors_reset = []
  end

# Arguments:
# * <i>message</i>: (<i>String</i>) message
#
# Returns: N/A
#
# Prints a FATAL ERROR message and exits. For internal problems only. Should
# never be called. 

  def shouldnt(message)
    print("** FATAL ERROR ** #{message}\n")
    exit(1)
  end

# Arguments:
# * <i>message</i>: (<i>String</i>) message
#
# Returns: N/A
#
# Prints the ERROR message and pushes it onto the <i>errors</i> stack.

  def error(message)
    print("** ERROR ** #{message}\n")
    self.errors.push(message)
    exit(1)
  end

# Arguments:
# * <i>message</i>: (<i>String</i>) message
# * <i>value</i>:   (<i>Arbitrary</i>) value to include after the message
#
# Returns: N/A
#
# Passes the following message to error: <i>message (value)</i>

  def error2(message, value)
    error("#{message} (#{value.to_s})")
  end

# Arguments:
# * <i>message1</i>: (<i>String</i>) 1st message
# * <i>value1</i>:   (<i>Arbitrary</i>) value for 1st message
# * <i>message2</i>: (<i>String</i>) 2nd message
# * <i>value2</i>:   (<i>Arbitrary</i>) value for  2nd message
#
# Returns: N/A
#
# Passes the following message to error: <i>message1 (value1) message2
# (value2)</i> 

  def error4(message1, value1, message2, value2)
    error("#{message1} (#{value1.to_s}) #{message2} (#{value2.to_s})")
  end

# No Arguments
# 
# Returns: N/A
#
# Resets the <i>errors</i> and <i>warnings</i> stacks to their initial state
# (empty).

  def errors_reset()
    self.errors = []
    self.warnings = []
  end

# No Arguments
# 
# Returns: <i>Array</i> of <i>errors</i>, <i>warnings</i>
#
# Returns an Array of the <i>errors</i> and <i>warnings</i> stacks

  def errors_return()
    [self.errors, self.warnings]
  end

# Arguments:
# * <i>message</i>: (<i>String</i>) message
#
# Returns: N/A
#
# Prints the WARNING message and pushes it onto the warnings stack.

  def warning(message)
    print("** WARNING ** #{message}\n")
    self.warnings.push(message)
    false
  end

# Arguments: 
# * <i>message</i>: (<i>String</i>) message
# * <i>value</i>:   (<i>Arbitrary</i>) value for message
#
# Returns: N/A
#
# Passes the following message to warning: message (value)

  def warning2(message, value)
    warning("#{message} (#{value.to_s})")
  end

# Arguments:
# * <i>type</i>: (<i>String</i>) type of UID
# * <i>uid</i>:  (<i>Atomic</i>) UID name
#
# Returns: <i>Boolean</i>
#
# Returns <i>true</i> if a UID of the specified <i>type</i> already
# exists. (UIDs are always cast to type <i>String</i> before being processed.)

  def uid_exists?(type, uid)
    shouldnt("Invalid Unique ID type: #{type}") unless UID_TYPES.include?(type)
    uid = uid.to_s
    self.unique_ids[type].include?(uid)
  end
    
# Arguments:
# * <i>type</i>: (<i>String</i>) type of UID
# * <i>uid</i>:  (<i>Atomic</i>) UID name
# * <i>warn</i>: (<i>Boolean</i>) indicates whether to produce a warning or error if the UID already exists
#
# Returns: <i>Boolean</i>
#
# If a UID of the specified <i>type</i> does not already exists, it is added
# to its UIDs list, and we return <i>true</i>.  If the UID already exists,
# then either an error message (<i>warn</i> is <i>false</i>) or a warning
# message is generated (<i>warn</i> is <i>true</i>), and <i>false</i> is
# returned. (UIDs are always cast to type <i>String</i> before being
# processed.)

  def uid_valid?(type, uid, warn = false)
    shouldnt("Invalid Unique ID type: #{type}") unless UID_TYPES.include?(type)
    uid = uid.to_s
    if (uid_exists?(type, uid))
      if (warn)
        warning("Duplicate #{type.capitalize} Unique ID: #{uid} (Ignored)")
      else
        error("Duplicate #{type.capitalize} Unique ID: #{uid}")
      end
    else
      self.unique_ids[type].push(uid)
      true
    end
  end

# Arguments:
# * <i>type</i>: (<i>String</i>) type of UID
# * <i>uid</i>:  (<i>Atomic</i>) UID name
#
# Returns: <i>Boolean</i>
#
# If a UID of the specified <i>type</i> does not already exists, it is added
# to its UIDs list, and we return <i>true</i>.  Otherwise, an error message is
# generated, and <i>false</i> is returned. (UIDs are always cast to type
# <i>String</i> before being processed.)

  def uid_singleton?(type, uid)
    shouldnt("Invalid Unique ID type: #{type}") unless UID_TYPES.include?(type)
    uid = uid.to_s
    if (!self.unique_ids.keys.include?(type) || (self.unique_ids[type].length == 0))
        self.unique_ids[type] = [uid]
        true
    else
      error("#{type.capitalize} Unique IDs already exist: #{uid}")
    end
  end

# Arguments:
# * <i>election</i>: (<i>Hash</i>) Election object
#
# Returns: N/A
#
# An Election is valid iff:
# 1. its UID is a singleton (it is the only Election UID, and thus unique), and 
# 2. its Reporting Groups are valid.

  def validate_election(election)
    uid_singleton?("election", election["ident"])
    validate_reporting_groups(election["reporting_group_list"])
  end

# Arguments:
# * <i>reporting_groups</i>: (<i>Array</i>) of Reporting Group objects
#
# Returns: N/A
#
# The Reporting Groups are valid iff:
# 1. they are all unique (there are no duplicate group names).

  def validate_reporting_groups(reporting_groups)
    reporting_groups.each { |rgid|
      uid_valid?("reporting group", rgid) }
  end

# Arguments:
# * <i>districts</i>: (<i>Array</i>) of District objects
#
# Returns: N/A
#
# The Districts are valid iff:
# 1. each District UID is unique (there are no duplicates).

  def validate_districts(districts)
    districts.each { |district|
      uid_valid?("district", district["ident"]) }
  end
  
# Arguments:
# * <i>precincts</i>: (<i>Array</i>) of Precinct objects
#
# Returns: N/A
#
# The Precincts are valid iff:
# 1. each Precinct UID is unique (there are no duplicates).

  def validate_precincts(precincts)
    precincts.each { |precinct|
      uid_valid?("precinct", precinct["ident"]) }
  end
  
# Arguments:
# * <i>contests</i>: (<i>Array</i>) of Contest objects
#
# Returns: N/A
#
# The Contests are valid iff:
# 1. each Contest UID is unique (there are no duplicates), and 
# 2. each Contest's District UID exists (was previously encountered by validate_districts and listed as a valid District UID). 
# This method also initializes the <i>contest_counts</i> attribute, by, for
# each Contest, using the Contest UID as a key under which to hash a
# zero-initialized Contest Count object for that Contest.

  def validate_contests(contests)
    contests.each { |contest|
      uid_valid?("contest", contest["ident"]) }
    contests.each do |contest|
      conid = contest["ident"].to_s
      did = contest["district_ident"].to_s
      error4("Non-existent Contest", conid, "District", did) unless
        uid_exists?("district", did)
      self.contest_counts[conid] = {"contest_ident"=>conid,
        "overvote_count"=>0,
        "undervote_count"=>0,
        "writein_count"=>0,
        "candidate_count_list"=>[]}
    end      
  end
  
# Arguments:
# * <i>candidates</i>: (<i>Array</i>) of Candidate objects
#
# Returns: N/A
#
# The Candidates are valid iff:
# 1. each Candidate UID is unique (there are no duplicates), and 
# 2. each Candidate's Contest UID exists (was previously encountered by validate_contests and listed as a valid Contest UID).  
# This method also completes the initialization of the <i>contest_counts</i>
# attribute, by, for each Candidate, adding a zero-initialized Candidate Count
# object to its corresponding Contest Count object.

  def validate_candidates(candidates)
    candidates.each { |candidate|
      uid_valid?("candidate", candidate["ident"]) }
    candidates.each do |candidate|
      canid = candidate["ident"].to_s
      conid = candidate["contest_ident"].to_s
      error4("Non-existent Candidate", canid, "Contest", conid) unless
        uid_exists?("contest", conid)
      self.contest_counts[conid]["candidate_count_list"].
        push({"candidate_ident"=>canid, "count"=>0})
    end
  end

# Arguments:
# * <i>questions</i>: (<i>Array</i>) of Question objects
#
# Returns: N/A
#
# The Questions are valid iff:
# 1. each Question UID is unique (there are no duplicates),
# 2. each Question's District UID exists (was previously encountered by validate_districts and listed as a valid District UID), and
# 3. no answers are duplicated.
# This method also initializes the <i>question_counts</i> attribute, by, for
# each Question, using its Question UID as a key under which to hash a
# zero-initialized Question Count object for that Question. 

  def validate_questions(questions)
    questions.each { |question|
      uid_valid?("question", question["ident"]) }
    questions.each do |question|
      qid = question["ident"].to_s
      did = question["district_ident"].to_s
      error4("Non-existent Question", qid, "District", did) unless
        uid_exists?("district", did)
      answers = question["answer_list"].collect {|answer| answer.to_s}
      error4("Duplicate Answers", answers, "for Question", qid) unless
        answers.length == answers.uniq.length
      self.question_counts[qid] = {"question_ident"=>qid,
        "overvote_count"=>0,
        "undervote_count"=>0,
        "answer_count_list"=>answers.collect {|ans| {"answer"=> ans,
            "count"=> 0}}}
    end
  end

# Arguments:
# * <i>counters</i>: (<i>Array</i>) of Counter objects
#
# Returns: N/A
#
# The Counters are valid iff:
# 1. each Counter UID is unique (there are no duplicates).

  def validate_counters(counters)
    counters.each { |counter|
      uid_valid?("counter", counter["ident"]) }
  end
  
# Arguments:
# * <i>expected_counts</i>: (<i>Array</i>) of Expected Count objects
#
# Returns: N/A
#
# The Expected Counts are valid iff:
# 1. each Counter UID exists,
# 2. each Precinct UID exists, and
# 3. all Reporting Groups exist.
# This method also initializes the <i>expected_counts</i> attribute.

  def validate_expected_counts(expected_counts)
    expected_counts.each do |ecount|
      cid = ecount["counter_ident"].to_s
      warning("Expected Count has invalid Counter: #{cid}") unless
        uid_exists?("counter", cid)
      rgid = ecount["reporting_group"].to_s
      warning("Expected Count #{cid} has invalid Reporting Group: #{rgid}") unless
        uid_exists?("reporting group",rgid)
      ecount["precinct_ident_list"].each do |pid|
        warning("Expected Count #{cid} has invalid Precinct: #{pid}") unless
          uid_exists?("precinct", pid)
        if (self.expected_counts[cid].is_a?(Hash))
          self.expected_counts[cid][rgid] = ecount["precinct_ident_list"]
        else
          self.expected_counts[cid] = {rgid=>ecount["precinct_ident_list"]}
        end
      end
    end
  end
  
# Arguments:
# * <i>contest_counts</i>: (<i>Array</i>) of Contest Count objects
#
# Returns: N/A
#
# The Contest Counts are valid iff, for each Contest Count:
# 1. the Contest UID exists,
# 2. the Contest UID is not duplicated (does not appear in a previously validated Contest Count), and
# 3. all Candidate Counts are valid.

  def validate_contest_counts(contest_counts)
    conids = []
    contest_counts.each do |contest_count|
      error2("Contest Count has invalid Contest", conid) unless
        uid_exists?("contest", conid = contest_count["contest_ident"].to_s)
      if (conids.include?(conid))
        error2("Contest Count has duplicate Contest", conid)
      else
        conids.push(conid)
      end
      validate_candidate_counts(contest_count["candidate_count_list"], conid)
    end
  end

# Arguments:
# * <i>candidate_counts</i>: (<i>Array</i>) of Candidate Count objects
# * <i>conid</i>: (<i>Atomic</i>) Contest UID for these Candidates Contest
#
# Returns: N/A
#
# The Candidate Counts are valid iff:
# 1. each Candidate belongs in the Contest specified by the Contest UID, 
# 2. no Candidates are duplicated, and 
# 3. no Candidates are missing from the Contest.

  def validate_candidate_counts(candidate_counts, conid)
    all_canids = self.contest_counts[conid]["candidate_count_list"].
      collect {|canc| canc["candidate_ident"].to_s}
    canids = []
    candidate_counts.each do |cancount|
      error2("Candidate Count has invalid Candidate", canid) unless
        uid_exists?("candidate",canid = cancount["candidate_ident"].to_s)
      if (canids.include?(canid))
        error4("Duplicate Contest Count", conid, "Candidate", canid)
      else
        canids.push(canid)
      end
      error4("Improper Contest Count", conid, "Candidate", canid) unless
        all_canids.include?(canid)
    end
    if (canids.length != all_canids.length)
      candiff = (all_canids - canids).inspect.gsub(/\"/,"")
      error4("Contest Count", conid, "missing Candidates", candiff)
    end
  end

# Arguments:
# * <i>question_counts</i>: (<i>Array</i>) of Question Count objects
#
# Returns: N/A
#
# The Question Counts are valid iff, for each Question Count:
# 1. the Question UID exists,
# 2. the Question UID is not duplicated (does not appear in a previously validated Question Count),
# 3. the Anwers all belong to the Question corresponding to the Question UID,
# 4. no Answer is duplicated, and 
# 5. there are no Answers missing from the Question.

  def validate_question_counts(question_counts)
    qids = []
    question_counts.each do |question_count|
      error2("Invalid Question Count", qid) unless
        uid_exists?("question",qid = question_count["question_ident"].to_s)
      if (qids.include?(qid))    
        error2("Duplicate Question Count", qid)
      else
        qids.push(qid)
      end
      all_answers = self.question_counts[qid]["answer_count_list"].
        collect {|anscount| anscount["answer"].to_s}
      answers = []
      question_count["answer_count_list"].each do |anscount|
        error4("Duplicate Question Count", qid, "Answer", answer) if
          answers.include?(answer = anscount["answer"].to_s)
        if (all_answers.include?(answer))
          answers.push(answer)
        else
          error4("Improper Question Count", qid, "Answer", answer)
        end
      end
      if (answers.length != all_answers.length)
        ansdiff = (all_answers - answers).inspect.gsub(/\"/,"")
        error4("Question Count", qid, "missing Answers", ansdiff)
      end
    end
  end

# Arguments:
# * <i>jurisdiction_definition</i>: (<i>Hash</i>) Jurisdiction Definition object
#
# Returns: <i>Array</i> of <i>errors</i>, <i>warnings</i>
#
# A Jurisdiction Definition is valid iff: 
# 2. the Jurisdiction UID is a singleton (it is the only Jurisdiction UID, and thus unique), 
# 3. the Districts are valid, and
# 4. the Precincts are valid.

  public
  def validate_jurisdiction_definition(jurisdiction_definition)
    errors_reset()
    uid_singleton?("jurisdiction", jurisdiction_definition["ident"])
    validate_precincts(jurisdiction_definition["precinct_list"])
    validate_districts(jurisdiction_definition["district_list"])
    errors_return()
  end

# Arguments:
# * <i>election_definition</i>: (<i>Hash</i>) Election Definition object
#
# Returns: <i>Array</i> of <i>errors</i>, <i>warnings</i>
#
# An Election Definition is valid iff: 
# 1. the Election is valid,
# 5. the Contests are valid,
# 6. the Candidates are valid,
# 7. the Questions are valid,
# 8. the Counters are valid, and
# 9. the Expected Counts are valid.

  public
  def validate_election_definition(election_definition)
    errors_reset()
    validate_election(election_definition["election"])
    validate_contests(election_definition["contest_list"])
    validate_candidates(election_definition["candidate_list"])
    validate_questions(election_definition["question_list"])
    validate_counters(election_definition["counter_list"])
    validate_expected_counts(election_definition["expected_count_list"])
    errors_return()
  end

# Arguments:
# * <i>counter_count</i>: (<i>Hash</i>) Counter Count object
#
# Returns: <i>Array</i> of <i>errors</i>, <i>warnings</i>
#
# A Counter Count is valid iff:
# 1. the Counter UID exists,
# 2. the Election UID exists (matches the only such UID),
# 3. the Jurisdiction UID exists (matches the only such UID),
# 4. the Precinct UID exists,
# 5. the Reporting Group exists,
# 6. the Contest Counts are valid, and
# 7. the Question Counts are valid.

  def validate_counter_count(counter_count)
    errors_reset()
    cid = counter_count["counter_ident"].to_s
    error2("Counter Count has invalid Counter", cid) unless
      uid_exists?("counter", cid)
    eid = counter_count["election_ident"].to_s
    error2("Counter Count has invalid Election", eid) unless
      uid_exists?("election", eid)
    jid = counter_count["jurisdiction_ident"].to_s
    error2("Counter Count has invalid Jurisdiction", jid) unless
      uid_exists?("jurisdiction", jid)
    pid = counter_count["precinct_ident"].to_s
    error2("Counter Count has invalid Precinct", pid) unless
      uid_exists?("precinct", pid)
    rgid = counter_count["reporting_group"].to_s
    warning2("Counter Count has invalid Reporting Group", rgid) unless
      uid_exists?("reporting group", rgid)
    error2("Invalid Contest Counts for Counter Count", cid) unless
      validate_contest_counts(counter_count["contest_count_list"])
    error2("Invalid Question Counts for Counter Count", cid) unless
      validate_question_counts(counter_count["question_count_list"])
    errors_return()
  end

# Arguments:
# * <i>tabulator_counts</i>: (<i>Hash</i>) Tabulator Count object
#
# Returns: <i>Array</i> of <i>errors</i>, <i>warnings</i>
#
# Re-initializes and determines if the Tabulator Count is valid, iff:
# 1. the Jurisdiction Definition is valid (this begins the initialization of the Tabulator, by initializing the <i>unique_ids</i> for Jurisdiction, Precincts and Districts),
# 2. the Election Definition is valid (this completes the initialization of the Tabulator, by initializing the remaining <i>unique_ids</i> and the <i>expected_counts</i> attributes),
# 3. the Election UID exists (matches the only such UID),
# 4. the Jurisdiction UID exists (matches the only such UID),
# 5. all Contest Counts are valid (this initializes the <i>contest_counts</i> attribute), and
# 6. all Question Counts are valid (this initializes the <i>question_counts</i> attribute).

  def validate_tabulator_count(tabulator_count)
    re_initialize()
    errors_reset()
    error("Tabulator Count has invalid Jurisdiction Definition") unless 
      validate_jurisdiction_definition(tabulator_count["jurisdiction_definition"])
    error("Tabulator Count has invalid Election Definition") unless 
      validate_election_definition(tabulator_count["election_definition"])
    eid = tabulator_count["election_ident"].to_s
    error2("Tabulator Count has invalid Election ID", eid) unless
      uid_exists?("election", eid)
    jid = tabulator_count["jurisdiction_ident"].to_s
    error2("Tabulator Count has invalid Jurisdiction ID", jid) unless
      uid_exists?("jurisdiction", jid)
    error("Tabulator Count has invalid Contest Counts") unless 
      validate_contest_counts(tabulator_count["contest_count_list"])
    error("Tabulator Count has invalid Question Counts") unless 
      validate_question_counts(tabulator_count["question_count_list"])
    tabulator_count["contest_count_list"].each do |contest_count|
      self.contest_counts[contest_count["contest_ident"]] = contest_count
    end
    tabulator_count["question_count_list"].each do |question_count|
      self.question_counts[question_count["question_ident"]] = question_count
    end
    errors_return()
  end

end
