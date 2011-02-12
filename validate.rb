#!/usr/bin/ruby

# OSDV Tabulator - TTV Tabulator Validation of Election Datasets
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

module Enumerable 
  def dups 
    inject({}) {|h,v| h[v]=h[v].to_i+1; h}.reject{|k,v| v==1}.keys
  end # collects the duplicate elements in an Enumerable type object
end

# The TabulatorValidate class is used to validate the data sets that are
# imported into the Tabulator.
#
# During the validation of a paired Jurisdiction Definition and Election
# Definition, it performs these additional operations:
# 1. Saves the names of all unique identifiers (UIDs)
# 3. Constructs zero-initialized Contest Counts for each Contest
# 4. Constructs zero-initialized Question Counts for each Question
# 5. Constructs a data structure that holds the Missing Expected Counts
#
# During the successful validation of a Counter Count, the final action is to
# update the Missing Counts data structure.

class TabulatorValidate

# All of the election objects that can be given unique identifiers (UIDs).

  UID_TYPES = ["jurisdiction", "district", "precinct", "election",
               "reporting group", "contest", "candidate", "question",
               "counter", "file"]

# <i>Array</i>, stack of error messages

  attr_accessor :errors

# <i>Array</i>, stack of warning messages

  attr_accessor :warnings

# <i>Hash</i> with <i>Key</i>: from <tt><b>UID_TYPES</b></tt>, <i>Value</i>:
# <i>Array</i> of  UIDs for that type; holds all the unique identifiers
# (UIDs), keyed by UID type

  attr_accessor :uids

# <i>Hash</i> with <i>Key</i>: Contest UID, <i>Value</i>: Contest Count; holds
# all the Contest Counts, keyed by Contest UID

  attr_accessor :counts_contests

# <i>Hash</i> with <i>Key</i>: Question UID, <i>Value</i>: Question Count;
# holds all the Question Counts, keyed by Question UID

  attr_accessor :counts_questions

# <i>Hash</i> with <i>Keys</i>: "total" (<i>Integer</i> number of individually
# expected counts); "precincts" <i>Array</i> of expected precinct UIDs;
# "finished" <i>Array</i> of finished precinct UIDs; "missing" <i>Array</i> of
# missing counts, each sub-array of which contains [Counter UID, Reporting
# Group, Precinct UID]; "accumulated" <i>Array</i> of
# accumulated counts, each sub-array of which contains [Counter UID, Reporting
# Group, Precinct UID]; and "expected" (expected counts, <i>Hash</i> with
# <i>Key</i>: Counter UID, <i>Value</i>: <i>Hash</i> with <i>Key</i>:
# Reporting Group, <i>Value</i>: <i>Hash</i> with <i>Key</i>: Precinct UID,
# <i>Value</i>: <i>Boolean</i>, <i>true</i> iff this particular count has been
# processed)

  attr_accessor :counts_missing

# <i>Hash</i> with <i>Key</i>: "tabulator_count", <i>Value</i>: Tabulator
# Count information; holds the Tabulator Count data set currently in effect.

  attr_accessor :tabulator_count

# Arguments:
# * <i>jurisdiction_definition</i>: (<i>Hash</i>) Jurisdiction Definition (optional)
# * <i>election_definition</i>: (<i>Hash</i>) Election Definition (optional)
# * <i>file</i>: (<i>String</i>) File name for new Tabulator Count (optional)
# * <i>tabulator_count</i>: (<i>Hash</i>) Tabulator Count (optional)
# 
# Returns: N/A
#
# Initializes all attributes, each set to empty for its particular type (zero
# for Integers), and then finishes by instantiating a Tabulator Count.  One
# set of arguments must be provided, either a Jurisdiction Definition,
# Election Definition, and File Name as the 1st, 2nd, and 3rd args, or a
# Tabulator Count as the 4th arg.
#
# If a Jurisdiction Definition, Election Definition, and File Name are
# provided, they are validated and used to construct a new Tabulator Count,
# which puts the Tabulator into its initial state, ready to accept counting
# data.
#
# If a Tabulator Count is provided, it is validated, which puts the Tabulator
# either into an initial state, or into a state where some votes have been
# counted, depending whether or not Counter Counts appear within the Tabulator
# Count.

  def initialize(jurisdiction_definition = false, election_definition = false,
                 file = false, tabulator_count = false)
    self.uids = Hash.new { |h,k| h[k] = [] }
    self.counts_contests = Hash.new { |h,k| h[k] = {} }
    self.counts_questions = Hash.new { |h,k| h[k] = {} }
    self.counts_missing = {"total"=>0, "precincts"=>[], "finished"=>[], "missing"=>[],
      "accumulated"=>[], "expected"=>Hash.new { |h,k| h[k] = {} }}
    self.errors = []
    self.warnings = []
    if (jurisdiction_definition)
      if (jurisdiction_definition.is_a?(Hash) &&
          jurisdiction_definition.keys.include?("jurisdiction_definition"))
        if (election_definition.is_a?(Hash) &&
            election_definition.keys.include?("election_definition"))
          self.tabulator_count =
            new_tabulator_count(jurisdiction_definition, election_definition, file)
        else
          shouldnt("Only an Election Definition may be the 2nd arg to Tabulator.new") 
        end
      else
        shouldnt("Only a Jurisdiction Definition may be the 1st arg to Tabulator.new")
      end
    elsif (tabulator_count)
      if (tabulator_count.is_a?(Hash) &&
          tabulator_count.keys.include?("tabulator_count"))
        self.tabulator_count = tabulator_count
        validate_tabulator_count(tabulator_count)
      else
        shouldnt("Only a Tabulator Count may be the 4th arg to Tabulator.new")
      end
    else
      shouldnt("Either a Tabulator Count or a Jurisdiction/Election Definition" +
               "must be passed to Tabulator.new")
    end
  end

# * <i>reset</i>: (<i>Boolean</i>) indicates whether to reset the <tt><b>errors</b></tt> stack (optional)
# 
# Returns: <i>Array</i>
#
# Returns the <tt><b>errors</b></tt> message stack, but resets it to empty first if <i>reset</i> is <i>true</i>

  def validation_errors(reset = false)
    self.errors = [] if reset
    self.errors
  end

# No Arguments
# 
# Returns: <i>Boolean</i>
#
# Returns <i>true</i> iff the <tt><b>errors</b></tt> message stack is non-empty.

  def validation_errors?()
    self.errors.length > 0
  end

# Arguments:
# * <i>reset</i>: (<i>Boolean</i>) indicates whether to reset the <tt><b>warnings</b></tt> stack (optional)
# 
# Returns: <i>Array</i>
#
# Returns the <tt><b>warnings</b></tt> message stack, but resets it to empty first if <i>reset</i> is <i>true</i>

  def validation_warnings(reset = false)
    self.warnings = [] if reset
    self.warnings
  end

# No Arguments
# 
# Returns: <i>Boolean</i>
#
# Returns <i>true</i> iff the <tt><b>warnings</b></tt> message stack is non-empty.

  def validation_warnings?()
    self.warnings.length > 0
  end

# Arguments:
# * <i>message1</i>: (<i>String</i>) message
# * <i>value1</i>:  (<i>Arbitrary</i>) value for message1 (optional)
#
# Returns: N/A
#
# Prints a FATAL ERROR message and exits. For internal problems only. Should
# never be called. 

  private
  def shouldnt(message1, value1 = "")
    message = "#{message1}" +
      (value1 == "" ? "" : " (#{value1.inspect.gsub(/[\"\[\]]/,"")})")
    print("** FATAL ERROR ** #{message}\n")
    $stdout.flush
    raise Foo # For debugging so we can see where the error came from
    exit(1)
  end

# Arguments:
# * <i>message1</i>: (<i>String</i>) 1st message
# * <i>value1</i>:   (<i>Arbitrary</i>) value for 1st message (optional)
# * <i>message2</i>: (<i>String</i>) 2nd message (optional)
# * <i>value2</i>:   (<i>Arbitrary</i>) value for 2nd message (optional)
# * <i>message3</i>: (<i>String</i>) 3rd message (optional)
#
# Returns: <i>false</i>
#
# Constructs the following ERROR message (with the optional bits left out):
# <i>message1 (value1) message2 (value2) message3</i>, and then pushes the
# message onto the <tt><b>errors</b></tt> stack.

  def error (message1, value1 = "", message2 = "", value2 = "", message3 = "")
    message = "#{message1}" +
      (value1 == "" ? "" : " (#{value1.to_s.gsub(/[\"\[\]]/,"")})") +
      (message2 == "" ? "" : " #{message2}") +
      (value2 == "" ? "" : " (#{value2.to_s})") +
      (message3 == "" ? "" : " #{message3}")
    self.errors.push(message)
    false
  end

# Arguments:
# * <i>message1</i>: (<i>String</i>) 1st message
# * <i>value1</i>:   (<i>Arbitrary</i>) value for st message (optional)
# * <i>message2</i>: (<i>String</i>) 2nd message (optional)
# * <i>value2</i>:   (<i>Arbitrary</i>) value for 2nd message (optional)
# * <i>message3</i>: (<i>String</i>) 3rd message (optional)
#
# Returns: <i>false</i>
#
# Constructs the following WARNING message (with the optional bits left out):
# <i>message1 (value1) message2 (value2) message3</i>, and then pushes the
# message onto the <tt><b>warnings</b></tt> stack.

  def warning (message1, value1 = "", message2 = "", value2 = "", message3 = "")
    message = "#{message1}" +
      (value1 == "" ? "" : " (#{value1.to_s.gsub(/[\"\[\]]/,"")})") +
      (message2 == "" ? "" : " #{message2}") +
      (value2 == "" ? "" : " (#{value2.to_s})") +
      (message3 == "" ? "" : " #{message3}")
    self.warnings.push(message)
    false
  end

# Arguments:
# * <i>type</i>: (<i>String</i>) type of UID, one of <tt><b>UID_TYPES</b></tt>
# * <i>uid</i>:  (<i>Atomic</i>) UID name
#
# Returns: <i>Boolean</i>
#
# Returns <i>true</i> if a UID named <i>uid</i>, of the specified <i>type</i>,
# already exists. (UIDs are always cast to type <i>String</i> before being
# processed.)

  def uid_exists?(type, uid)
    shouldnt("Invalid UID type", type) unless UID_TYPES.include?(type)
    uid = uid.to_s
    self.uids[type].include?(uid)
  end

# Arguments:
# * <i>type</i>: (<i>String</i>) type of UID, one of <tt><b>UID_TYPES</b></tt>
#
# Returns: <i>Boolean</i>
#
# Returns <i>true</i> if one or more UIDs of the specified <i>type</i> already
# exist.

  def uids_exist?(type)
    shouldnt("Invalid UID type", type) unless UID_TYPES.include?(type)
    return (self.uids.keys.include?(type) && self.uids[type].keys.length > 0)
  end

# Arguments:
# * <i>type</i>: (<i>String</i>) type of UID, one of <tt><b>UID_TYPES</b></tt>
# * <i>uid</i>:  (<i>Atomic</i>) UID
#
# Returns: N/A
#
# The UID is added to its associated UIDs list. (UIDs are always cast to type
# <i>String</i> before being processed.)

  def uid_add(type, uid)
    shouldnt("Invalid UID type", type) unless UID_TYPES.include?(type)
    uid = uid.to_s
    shouldnt("Pre-existing UID", uid) if self.uids[type].include?(uid)
    self.uids[type].push(uid)
  end

# Arguments:
# * <i>jurisdiction_definition</i>: (<i>Hash</i>) Jurisdiction Definition
# * <i>election_definition</i>: (<i>Hash</i>) Election Definition
# * <i>file</i>: (<i>String</i>) File name for new Tabulator Count
#
# Returns: <i>Hash</i>
#
# Returns an initial Tabulator Count constructed from the information provided
# by the Jurisdiction Definition, Election Definition, and File.  Uses the
# side effects of the validation of the Jurisdiction and Election Definitions
# (the initialization of the <tt><b>counts_contests</b></tt> and
# <tt><b>counts_questions</b></tt> attributes) to create and insert
# zero-initialized Contest and Question Counts into the Tabulator Count, and
# sets its Counter Count to the empty array.

  def new_tabulator_count(jurisdiction_definition, election_definition, file)
    jdinfo = jurisdiction_definition["jurisdiction_definition"]
    validate_jurisdiction_definition(jdinfo)
    edinfo = election_definition["election_definition"]
    validate_election_definition(edinfo)
    self.tabulator_count = 
     {"tabulator_count"=>
      {"election_ident"=>edinfo["election"]["ident"],
        "jurisdiction_ident"=>jdinfo["ident"],
        "audit_header"=>
        {"software"=>"TTV Tabulator",
          "file_ident"=>file,
          "operator"=>"Jeffrey Valjean Cook",
          "create_date"=>Time.new.strftime("%Y-%m-%d %H:%M:%S")},
        "jurisdiction_definition"=>jdinfo,
        "election_definition"=>edinfo,
        "contest_count_list"=>self.counts_contests.keys.collect { |k|
          self.counts_contests[k] },
        "question_count_list"=>self.counts_questions.keys.collect { |k|
          self.counts_questions[k] },
        "counter_count_list"=>[],
        "state"=>"INITIAL"}}
  end

# Arguments:
# * <i>jurisdiction_definition</i>: (<i>Hash</i>) Jurisdiction Definition object
#
# Returns: N/A
#
# A Jurisdiction Definition is valid iff: 
# 1. the Districts are valid, and
# 2. the Precincts are valid.
#
# If the Jurisdiction UID is not unique and solo, then there is a serious
# internal error, as this method should only be called in an initial state.

  def validate_jurisdiction_definition(jurisdiction_definition)
    if (uids_exist?("jurisdiction"))
      shouldnt("Pre-existing Jurisdiction UIDs",
               self.uids["jurisdiction"].keys.inspect)
    else
      uid_add("jurisdiction", jurisdiction_definition["ident"])
    end
    validate_precincts(jurisdiction_definition["precinct_list"])
    validate_districts(jurisdiction_definition["district_list"])
  end

# Arguments:
# * <i>precincts</i>: (<i>Array</i>) of Precinct objects
#
# Returns: N/A
#
# The Precincts are valid iff:
# 1. each Precinct UID is uniquely defined.

  def validate_precincts(precincts)
    uniq_precincts = []
    precincts.each do |precinct|
      if (uid_exists?("precinct", pid = precinct["ident"].to_s))
        if (uniq_precincts.include?(precinct))
          warning("Duplicate Precinct Declaration", pid, "in Jurisdiction Definition")
        else
          error("Non-Unique Precinct UID", pid, "in Jurisdiction Definition")
        end
      else
        uniq_precincts.push(precinct)
        uid_add("precinct", pid)
      end
    end
  end
  
# Arguments:
# * <i>districts</i>: (<i>Array</i>) of District objects
#
# Returns: N/A
#
# The Districts are valid iff:
# 1. each District UID is uniquely defined.

  def validate_districts(districts)
    uniq_districts = []
    districts.each do |district|
      if (uid_exists?("district", did = district["ident"].to_s))
        if (uniq_districts.include?(district))
          warning("Duplicate District Declaration", did, "in Jurisdiction Definition")
        else
          error("Non-Unique District UID", did, "in Jurisdiction Definition")
        end
      else 
        uniq_districts.push(district)
        uid_add("district", did)
      end
    end
  end

# Arguments:
# * <i>object</i>:  (<i>Hash</i>) Election Definition or Counter Count
# * <i>name</i>:    (<i>String</i>) proper name of object above
# * <i>errwarn</i>: (<i>Boolean</i>) indicates whether to check existing errors and warnings (when <i>true</i>) or insert them into the object 
#
# Returns: N/A
#
# If <i>errwarn</i> is <i>true</i>, check to ensure that the errors and
# warnings stored in the object match exactly the current errors and warnings
# of the Tabulator.  They should match exactly, because these were the errors
# and warnings generated last time this object was processed (we are
# re-instantiating the Tabulator). If they do not match, we have a fatal
# internal error, because this should never happen.  If <i>errwarn</i> is
# <i>false</i>, this is the first time this object has been processed by the
# Tabulator, so store any errors and warnings inside the object, for later
# consistency checking.

  def validate_errors_warnings (object, name, errwarn)
    if (errwarn)
      if (object['error_list'] == validation_errors())
        if (object['warning_list'] == validation_warnings())
          validation_errors(true)
          validation_warnings(true)
        else
          shouldnt("Warnings mismatch in #{name}")
        end
      elsif (object['warning_list'] == validation_warnings())
        shouldnt("Errors mismatch in #{name}")
      else
        shouldnt("Errors and Warnings mismatch in #{name}")
      end
    else
      object['error_list']= validation_errors()
      object['warning_list']= validation_warnings()
    end
  end
  
# Arguments:
# * <i>election_definition</i>: (<i>Hash</i>) Election Definition object
# * <i>errwarn</i>: (<i>Boolean</i>) (see validate_errors_warnings)
#
# Returns: N/A
#
# An Election Definition is valid iff: 
# 1. the Election is valid,
# 2. the Contests are valid,
# 3. the Candidates are valid,
# 4. the Questions are valid,
# 5. the Counters are valid,
# 6. the Reporting Groups are valid (if present, warning otherwise), and
# 6. the Expected Counts are valid (if present, warning otherwise).

  def validate_election_definition(election_definition, errwarn = false)
    jid = election_definition["jurisdiction_ident"].to_s
    error("Non-Existent Jurisdiction UID", jid, "in Election Definition") unless 
      uid_exists?("jurisdiction", jid) 
    validate_election(election_definition["election"])
    validate_contests(election_definition["contest_list"])
    validate_candidates(election_definition["candidate_list"])
    validate_questions(election_definition["question_list"])
    validate_counters(election_definition["counter_list"])
    if (0 == election_definition["reporting_group_list"].length)
      warning("Missing ALL Reporting Groups, None Present in Election Definition")
    else
      validate_reporting_groups(election_definition["reporting_group_list"])
    end
    if (0 == election_definition["expected_count_list"].length)
      warning("Missing ALL Expected Counts, None Present in Election Definition")
    else
      validate_expected_counts(election_definition["expected_count_list"])
    end
    validate_errors_warnings(election_definition, "Election Definition", errwarn)
  end

# Arguments:
# * <i>election</i>: (<i>Hash</i>) Election object
#
# Returns: N/A
#
# An Election is valid iff:
# 1. the Election UID is unique and no other such are present.
#
# If the Election UID is not unique and solo, then there is a serious internal
# error, as this method should only be called when in an initial state.

  def validate_election(election)
    if (uids_exist?("election"))
      shouldnt("Pre-existing Election UIDs", self.uids["election"].keys.inspect)
    else
      uid_add("election", election["ident"])
    end
  end

# Arguments:
# * <i>contests</i>: (<i>Array</i>) of Contest objects
#
# Returns: N/A
#
# The Contests are valid iff:
# 1. each Contest UID is uniquely defined, and
# 2. each Contest"s District UID exists (validate_districts added it to the set of  District UIDs). 
# This method also initializes the <tt><b>counts_contests</b></tt> attribute,
# by, for each Contest, using the Contest UID as a key under which to hash a
# zero-initialized Contest Count object for that Contest.

  def validate_contests(contests)
    uniq_contests = []
    contests.each do |contest|
      if (uid_exists?("contest", conid = contest["ident"].to_s))
        if (uniq_contests.include?(contest))
          warning("Duplicate Contest Declaration", conid, "in Election Definition")
        else
          error("Non-Unique Contest UID", conid, "in Election Definition")
        end
      else
        uniq_contests.push(contest)
        uid_add("contest", conid)
      end
    end
    contests.each do |contest|
      conid = contest["ident"].to_s
      did = contest["district_ident"].to_s
      error("Non-Existent District UID", did, "in Contest UID", conid, "in Election Definition") unless
        uid_exists?("district", did)
      self.counts_contests[conid] = {"contest_ident"=>conid,
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
# 1. each Candidate UID is uniquely defined,
# 2. each Candidate"s Contest UID exists (validate_contests added it to the set of Contest UIDs). 
# This method also completes the initialization of the
# <tt><b>counts_contests</b></tt> attribute, by, for each Candidate, adding a
# zero-initialized Candidate Count object to its corresponding Contest Count
# object. 

  def validate_candidates(candidates)
    uniq_candidates = []
    candidates.each do |candidate|
      if (uid_exists?("candidate", canid = candidate["ident"].to_s))
        if (uniq_candidates.include?(candidate))
          warning("Duplicate Candidate Declaration", canid, "in Election Definition")
        else
          error("Non-Unique Candidate UID", canid, "in Election Definition")
        end
      else
        uniq_candidates.push(candidate)
        uid_add("candidate", canid)
      end
    end
    candidates.each do |candidate|
      canid = candidate["ident"].to_s
      conid = candidate["contest_ident"].to_s
      if (uid_exists?("contest", conid))
        self.counts_contests[conid]["candidate_count_list"].
          push({"candidate_ident"=>canid, "count"=>0})
      else 
        error("Non-Existent Contest UID", conid, "for Candidate UID", canid, "in Election Definition")
      end
    end
  end

# Arguments:
# * <i>questions</i>: (<i>Array</i>) of Question objects
#
# Returns: N/A
#
# The Questions are valid iff:
# 1. each Question UID is uniquely defined,
# 2. each Question"s District UID exists (validate_districts added it to the set of  District UIDs), and
# 3. no Answers are duplicated.
# This method also initializes the <tt><b>counts_questions</b></tt> attribute,
# by, for each Question, using its Question UID as a key under which to hash a 
# zero-initialized Question Count object for the Question. 
  
  def validate_questions(questions)
    uniq_questions = []
    questions.each do |question|
      qid = question["ident"].to_s
      if (uid_exists?("question", qid))
        if (uniq_questions.include?(question))
          warning("Duplicate Question Declaration", qid, "in Election Definition")
        else
          error("Non-Unique Question UID", qid, "in Election Definition")
        end
      else
        uniq_questions.push(question)
        uid_add("question", qid)
        did = question["district_ident"].to_s
        error("Non-Existent District UID", did, "for Question UID", qid, "in Question") unless
          uid_exists?("district", did)
        answers = question["answer_list"].collect {|answer| answer.to_s}
        unless (answers.length == answers.uniq.length)
          ansdups = answers.dups.inspect
          error("Duplicate Answers", ansdups, "for Question UID", qid, "in Question")
        end
        self.counts_questions[qid] = {"question_ident"=>qid,
          "overvote_count"=>0,
          "undervote_count"=>0,
          "answer_count_list"=>answers.collect {|ans| {"answer"=> ans,
              "count"=> 0}}}
      end
    end
  end

# Arguments:
# * <i>counters</i>: (<i>Array</i>) of Counter objects
#
# Returns: N/A
#
# The Counters are valid iff:
# 1. each Counter UID is uniquely defined.

  def validate_counters(counters)
    uniq_counters = []
    counters.each do |counter|
      if (uid_exists?("counter", counid = counter["ident"].to_s))
        if (uniq_counters.include?(counter))
          warning("Duplicate Counter Declaration", counid, "in Election Definition")
        else
          error("Non-Unique Counter UID", counid, "in Election Definition")
        end
      else
        uniq_counters.push(counter)
        uid_add("counter", counid)
      end
    end
  end
  
# Arguments:
# * <i>reporting_groups</i>: (<i>Array</i>) of Reporting Group objects
#
# Returns: N/A
#
# The Reporting Groups are valid iff:
# 1. they are all unique (there are no duplicate group names).

  def validate_reporting_groups(reporting_groups)
    reporting_groups.each do |rg|
      if (uid_exists?("reporting group", rg))
        warning("Duplicate Reporting Group", rg, "in Election Definition")
      else
        uid_add("reporting group", rg)
      end
    end
  end

# Arguments:
# * <i>expected_counts</i>: (<i>Array</i>) of Expected Count objects
#
# Returns: N/A
#
# The Expected Counts are valid iff:
# 1. each Counter UID exists,
# 2. each Reporting Group exists, and
# 3. each Precinct UID exists.
#
# Warnings are generated unless all Counters, Reporting Groups, and Precincts
# are mentioned in the Expected Counts.
#
# This method also initializes the <tt><b>counts_missing</b></tt> attribute.

  def validate_expected_counts(expected_counts)
    exp_cids = []
    exp_rgs = []
    exp_pids = []
    expected_counts.each do |ecount|
      cid = ecount["counter_ident"].to_s
      rg = ecount["reporting_group"].to_s
      error("Non-Existent Counter UID", cid, "in Expected Count") unless
        uid_exists?("counter", cid)
      error("Non-Existent Reporting Group", rg, "for Counter UID", cid, "in Expected Count") unless
        uid_exists?("reporting group",rg)
      ecount["precinct_ident_list"].each do |pid|
        pid = pid.to_s
        error("Non-Existent Precinct UID", pid, "for Counter UID", cid, "in Expected Count") unless
          uid_exists?("precinct", pid)
      end
      exp_cids.push(cid) unless exp_cids.include?(cid)
      exp_rgs.push(rg) unless exp_rgs.include?(rg)
      ecount["precinct_ident_list"].each do |pid|
        pid = pid.to_s
        exp_pids.push(pid) unless exp_pids.include?(pid)
        update_expected_counts(cid, rg, pid)
      end
    end
    self.counts_missing["precincts"] = exp_pids
    self.counts_missing["finished"] = []
    diff_cids = (self.uids["counter"] - exp_cids)
    warning("Missing Counter UIDs", diff_cids, "from Expected Counts") unless
      (diff_cids.length == 0)
    diff_rgs = (self.uids["reporting group"] - exp_rgs)
    warning("Missing Reporting Groups", diff_rgs, "from Expected Counts") unless
      (diff_rgs.length == 0)
    diff_pids = (self.uids["precinct"] - exp_pids)
    warning("Missing Precinct UIDs", diff_pids, "from Expected Counts") unless
      (diff_pids.length == 0)
  end

# Arguments:
# * <i>cid</i>: (<i>String</i>) Counter UID
# * <i>rg</i>:  (<i>String</i>) Reporting Group name
# * <i>pid</i>: (<i>String</i>) Precinct UID
#
# Returns: N/A
#
# Updates the "expected" part of the <tt><b>counts_missing</b></tt> attribute,
# by setting <tt><b>counts_missing['expected'][cid][rg][pid]</b></tt> to
# <i>false</i>.  It is set to <i>true</i> when the appropriate count is
# accumulated by the Tabulator.

  def update_expected_counts (cid, rg, pid)
    if (self.counts_missing["expected"][cid].is_a?(Hash))
      if (self.counts_missing["expected"][cid][rg].is_a?(Hash))
        warning("Duplicate Expected Count", "#{cid}, #{rg}, #{pid}", "in Election Definition") if
          self.counts_missing["expected"][cid][rg].keys.include?(pid)
        self.counts_missing["expected"][cid][rg][pid] = false
      else
        self.counts_missing["expected"][cid][rg] = {pid=>false}
      end
    else
      self.counts_missing["expected"][cid] = {rg=>{pid=>false}}
    end
    unless (self.counts_missing["missing"].include?([cid, rg, pid]))
      self.counts_missing["total"] += 1
      self.counts_missing["missing"].push([cid, rg, pid])
    end
  end    


# Arguments:
# * <i>counter_count</i>: (<i>Hash</i>) Counter Count object
# * <i>errwarn</i>: (<i>Boolean</i>) (see validate_errors_warnings)
#
# Returns: N/A
#
# A Counter Count is valid iff:
# 1. the Counter UID exists,
# 2. the Precinct UID exists,
# 3. the Election UID exists (matches the only such UID),
# 4. the Jurisdiction UID exists (matches the only such UID),
# 5. the Audit File UID is unique (not a duplicate),
# 6. the Contest Counts are valid, and
# 7. the Question Counts are valid.
#
# A Warning is generated if the Reporting Group is not recognized.
#
# If the Counter Count is valid, the final act of this method is to update the
# <tt><b>counts_missing</b></tt> attribute to reflect the presence of this new
# count.

  public
  def validate_counter_count(counter_count, errwarn = false)
    ccinfo = counter_count["counter_count"]
    cid = ccinfo["counter_ident"].to_s
    error("Non-Existent Counter UID", cid, "in Counter Count") unless
      (uid_exists?("counter", cid))
    rg = ccinfo["reporting_group"].to_s
    warning("Non-Existent Reporting Group", rg, "for Counter UID", cid, "in Counter Count") unless
      (uid_exists?("reporting group", rg))
    pid = ccinfo["precinct_ident"].to_s
    error("Non-Existent Precinct UID", pid, "for Counter UID", cid, "in Counter Count") unless
      (uid_exists?("precinct", pid))
    jid = ccinfo["jurisdiction_ident"].to_s
    error("Non-Existent Jurisdiction UID", jid, "for Counter UID", cid, "in Counter Count") unless 
      uid_exists?("jurisdiction", jid) 
    eid = ccinfo["election_ident"].to_s
    error("Non-Existent Election UID", eid, "for Counter UID", cid, "in Counter Count") unless 
      uid_exists?("election", eid)
    fid = ccinfo["audit_header"]["file_ident"]
    error("Non-Unique File UID", fid, "in Counter Count") if
      uid_exists?("file", fid)
    validate_contest_counts(ccinfo["contest_count_list"])
    validate_question_counts(ccinfo["question_count_list"])
    update_counts_missing(cid, rg, pid) unless validation_errors?
    uid_add("file", fid) unless validation_errors?
    validate_errors_warnings(counter_count, "Counter Count", errwarn)
  end

# Arguments:
# * <i>counts_contests</i>: (<i>Array</i>) of Contest Count objects
#
# Returns: N/A
#
# The Contest Counts are valid iff, for each Contest Count:
# 1. the Contest UID exists,
# 2. the Contest UID is not duplicated (does not appear in a previously validated Contest Count),
# 3. all Candidate Counts are valid, and
# 4. all Contests appear in the Contest Count.

  private
  def validate_contest_counts(contest_counts)
    all_conids = self.counts_contests.keys
    conids = []
    contest_counts.each do |contest_count|
      conid = contest_count["contest_ident"].to_s
      if (! uid_exists?("contest", conid))
        error("Non-Existent Contest UID", conid, "in Contest Count")
      elsif (conids.include?(conid))
        error("Duplicate Contest UID", conid, "in Contest Count")
      else
        conids.push(conid)
        validate_candidate_counts(contest_count["candidate_count_list"], conid)
      end
    end
    if (conids.length != all_conids.length)
      condiff = (all_conids - conids).inspect
      error("Missing Contest UIDs", condiff, "in Contest Counts")
    end
  end

# Arguments:
# * <i>candidate_counts</i>: (<i>Array</i>) of Candidate Count objects
# * <i>conid</i>: (<i>Atomic</i>) Contest UID for these Candidates Contest
#
# Returns: N/A
#
# The Candidate Counts are valid iff:
# 1. each Candidate UID exists,
# 2. each Candidate belongs to the Contest,
# 3. no Candidate is duplicated, and 
# 4. no Candidates are missing from the Contest.

  def validate_candidate_counts(candidate_counts, conid)
    all_canids = self.counts_contests[conid]["candidate_count_list"].
      collect {|canc| canc["candidate_ident"].to_s}
    canids = []
    candidate_counts.each do |cancount|
      canid = cancount["candidate_ident"].to_s
      if (! uid_exists?("candidate", canid))
        error("Non-Existent Candidate UID", canid, "for Contest UID", conid, "in Contest Count")
      elsif (! all_canids.include?(canid))
        error("Improper Candidate UID", canid, "for Contest UID", conid, "in Contest Count")
      elsif (canids.include?(canid))
        error("Duplicate Candidate UID", canid, "for Contest UID", conid, "in Contest Count")
      else
        canids.push(canid)
      end
    end
    if (canids.length != all_canids.length)
      candiff = (all_canids - canids).inspect
      error("Missing Candidate UIDs", candiff, "for Contest UID", conid, "in Contest Count")
    end
  end

# Arguments:
# * <i>counts_questions</i>: (<i>Array</i>) of Question Count objects
#
# Returns: N/A
#
# The Question Counts are valid iff, for each Question Count:
# 1. the Question UID exists,
# 2. the Question is not duplicated (does not appear in a previously validated Question Count),
# 3. no Answer is duplicated within a Question Count,
# 4. each Answer belongs to its Question Count,
# 5. there are no Answers missing from a Question Count, and
# 6. there are no Questions missing from the Question Counts.

  def validate_question_counts(question_counts)
    all_qids = self.counts_questions.keys
    qids = []
    question_counts.each do |question_count|
      qid = question_count["question_ident"].to_s
      if (! uid_exists?("question", qid))
        error("Non-Existent Question UID", qid, "in Question Count")
      else
        if (qids.include?(qid))    
          error("Duplicate Question UID", qid, "in Question Count")
        else
          qids.push(qid)
        end
        all_answers = self.counts_questions[qid]["answer_count_list"].
          collect {|anscount| anscount["answer"].to_s}
        answers = []
        question_count["answer_count_list"].each do |anscount|
          answer = anscount["answer"].to_s
          if (all_answers.include?(answer))
            if (answers.include?(answer))
              error("Duplicate Answer", answer, "for Question UID", qid, "in Question Count")
            else
              answers.push(answer)
            end
          else
            error("Improper Answer", answer, "for Question UID", qid, "in Question Count")
          end
        end
        if (answers.length != all_answers.length)
          ansdiff = (all_answers - answers).inspect
          error("Missing Answers", ansdiff, "for Question UID", qid, "in Question Count")
        end
      end
    end
    if (qids.length != all_qids.length)
      qdiff = (all_qids - qids).inspect
      error("Missing Question UIDs", qdiff, "in Question Counts")
    end
  end

# Arguments:
# * <i>cid</i>: (<i>String</i>) Counter UID
# * <i>rg</i>:  (<i>String</i>) Reporting Group name
# * <i>pid</i>: (<i>String</i>) Precinct UID
#
# Returns: N/A
#
# First, the Tabulator state is set to ACCUMULATING if it is currently
# INITIAL. The <tt><b>counts_missing</b></tt> attribute is updated using the
# information from the (previously validated) Counter Count, provided the
# count was expected. The
# <tt><b>counts_missing['expected'][cid][rg][pid]</b></tt> attribute is set to
# <i>false</i> and the corresponding sub-array ([cid, rg, pid]) in
# <tt><b>counts_missing['missing']</b></tt> is deleted.  If expected counts
# were defined and this was the last missing count, then the Tabulator state
# is set to DONE.

  def update_counts_missing(cid, rg, pid)
    self.tabulator_count['tabulator_count']['state'] = 'ACCUMULATING' if
      self.tabulator_count['tabulator_count']['state'] == 'INITIAL'
    warning("Unexpected Counter Count", "#{cid}, #{rg}, #{pid}", "After Tabulator DONE") if
      (self.tabulator_count['tabulator_count']['state'] == 'DONE')
    if (self.counts_missing["accumulated"].include?([cid, rg, pid]))
      error("Duplicate Counter Count", "#{cid}, #{rg}, #{pid}", "Input to Tabulator")
    else
      self.counts_missing["accumulated"].push([cid, rg, pid])
      if (really_expected?(cid, rg, pid))
        if (self.counts_missing["expected"][cid][rg][pid] == false)
          self.counts_missing["accumulated"].push([cid, rg, pid])
          self.counts_missing["expected"][cid][rg][pid] = true
          self.counts_missing["missing"].delete_if {|cid0, rg0, pid0|
            ((cid == cid0) && (rg == rg0) && (pid == pid0)) }
          self.counts_missing["finished"] =
            self.counts_missing["precincts"].select { |pid|
            self.counts_missing["missing"].all? {|cid0, rg0, pid0| (pid != pid0)}}
          self.tabulator_count['tabulator_count']['state'] = 'DONE' if
            ((self.counts_missing["expected"].keys.length > 0) &&
             (self.counts_missing["missing"].length == 0))
        end
      end
    end
  end

# Arguments:
# * <i>cid</i>: (<i>String</i>) Counter UID
# * <i>rg</i>:  (<i>String</i>) Reporting Group name
# * <i>pid</i>: (<i>String</i>) Precinct UID
#
# Returns: <i>Boolean</i>
#
# Returns <i>true</i> iff this count is in the list of expected counts.
# Generates warnings if this is not the case.

  def really_expected?(cid, rg, pid)
    expected = self.counts_missing["expected"]
    shouldnt("Counter Count has invalid Counter UID", cid) unless
      uid_exists?("counter", cid)
    shouldnt("Counter Count for #{cid} has invalid Precinct UID", pid) unless 
      uid_exists?("precinct", pid)
    if (expected.keys.include?(cid))
      if ((expected[cid].is_a?(Hash) && expected[cid].keys.include?(rg)))
        if ((expected[cid][rg].is_a?(Hash) && expected[cid][rg].keys.include?(pid)))
          true
        else
          warning("Unexpected Precinct UID", pid, "for Counter UID", cid, "in Counter Count")
        end
      elsif uid_exists?("reporting group", rg)
        warning("Unexpected Reporting Group", rg, "for Counter UID", cid, "in Counter Count")
      else
        false
      end
    else
      warning("Unexpected Counter UID", cid, "in Counter Count")
    end
  end

# Arguments:
# * <i>tabulator_count</i>: (<i>Hash</i>) Tabulator Count object
#
# Returns: N/A
#
# This methods expects to be called only when the Tabulator is in its initial
# state.  A Tabulator Count is valid iff:
# 1. the Jurisdiction Definition is valid (this begins the initialization of the Tabulator, by initializing the <tt><b>uids</b></tt> for Jurisdiction, Precincts and Districts),
# 2. the Election Definition is valid (this completes the initialization of the Tabulator, by initializing the remaining <tt><b>uids</b></tt> and the <tt><b>counts_contests</b></tt>, <tt><b>counts_questions</b></tt>, and <tt><b>counts_missing</b></tt> attributes),
# 3. the Election UID exists (matches the only such UID),
# 4. the Jurisdiction UID exists (matches the only such UID),
# 5. all Contest Counts are valid (this finalizes the <tt><b>counts_contests</b></tt> attribute), and
# 6. all Question Counts are valid (this finalizes the <tt><b>counts_questions</b></tt> attribute).
# 7. all Counter Counts are valid (this finalizes the <tt><b>counts_missing</b></tt> attribute).
#
# An invalid Tabulator Count could imply the presence of a serious and fatal
# internal error in the Tabulator, as all Tabulator Counts are validated
# before being output.

  def validate_tabulator_count(tabulator_count)
    state = tabulator_count["tabulator_count"]['state']
    tabulator_count["tabulator_count"]['state'] = 'INITIAL'
    errwarn = true
    self.tabulator_count = tabulator_count
    tcinfo = tabulator_count["tabulator_count"]
    validate_jurisdiction_definition(tcinfo["jurisdiction_definition"])
    validate_election_definition(tcinfo["election_definition"], errwarn)
    eid = tcinfo["election_ident"].to_s
    shouldnt("Non-Existent Election UID (#{eid}) in Tabulator Count") unless
      uid_exists?("election", eid)
    jid = tcinfo["jurisdiction_ident"].to_s
    shouldnt("Non-Existent Jurisdiction UID (#{jid}) in Tabulator Count") unless
      uid_exists?("jurisdiction", jid)
    validate_contest_counts(tcinfo["contest_count_list"])
    validate_question_counts(tcinfo["question_count_list"])
    tcinfo["contest_count_list"].each do |contest_count|
      self.counts_contests[contest_count["contest_ident"]] = contest_count
    end
    tcinfo["question_count_list"].each do |question_count|
      self.counts_questions[question_count["question_ident"]] = question_count
    end
    validate_counter_counts(tcinfo["counter_count_list"], errwarn)
    endstate = tabulator_count["tabulator_count"]['state']
    shouldnt("Tabulator end state invalid (#{endstate}) expecting: #{state}") if
      (endstate != state)
  end

# Arguments:
# * <i>counter_counts</i>: (<i>Array</i>) of Counter Count objects
# * <i>errwarn</i>: (<i>Boolean</i>) (see validate_errors_warnings)
#
# Returns: N/A
#
# The Counter Counts are valid iff each Counter Count is valid.

  def validate_counter_counts(counter_counts, errwarn = false)
    counter_counts.each { |counter_count|
      validate_counter_count(counter_count, errwarn) }
  end
  
end
