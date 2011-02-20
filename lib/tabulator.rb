#!/usr/bin/ruby

# OSDV Tabulator - TTV Tabulator
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

require "lib/validator"

# The Tabulator class inherits the capabilities of the TabulatorValidator
# class, and provides additional functionality for determining the Tabulator
# State, for writing out a Tabulator spreadsheet, and for counting votes by
# processing Counter Counts and then updating the Tabulator Count. The
# Tabulator states are:
# * EMPTY:        Waiting for Jurisdiction and Election Definitions
# * INITIAL:      Waiting for 1st Counter Count, M Missing
# * ACCUMULATING: Waiting for N Counter Counts, M Missing
# * DONE:         All N Expected Counter Counts Accumulated

class Tabulator < TabulatorValidator

# No Arguments
#
# Returns: <i>Array</i>
#
# Returns an <i>Array</i> of 4 items:
# * a string holding the current state of the Tabulator,
# * an <i>Array</i> of the still-missing Expected Counts,
# * an <i>Array</i> of the Precincts whose counts are expected and finished, and
# * an <i>Integer</i> represeting the total number of Expected Counts.
# Of the four possible Tabulator states, the Tabulator is only capable of
# reporting on the last three, because it is never in the EMPTY state
# while it is running.

  def tabulator_state()
    state = self.tabulator_count["tabulator_count"]["state"]
    expect = self.counts_expected.length
    count = (expect == 1 ? "1 Expected Count" : "#{expect.to_s} Expected Counts")
    case state
    when "INITIAL"
      ["INITIAL (Waiting for #{count})", [], [], 0]
    when "DONE"
      ["DONE (All #{expect.to_s} Expected Counts Accumulated)", [], [], 0]
    when "ACCUMULATING"
      missing = (self.counts_expected - self.counts_accumulated)
      finished = self.uids["precinct"].select { |pid|
        self.counts_expected.any? {|cid0, rg0, pid0| (pid == pid0) } &&
        missing.all? {|cid0, rg0, pid0| (pid != pid0) } }
      ["ACCUMULATING (#{missing.length.to_s} Missing from #{count})",
       missing,
       finished,
       expect ]
    else
      shouldnt("Invalid Tabulator State: #{state.to_s}")
    end
  end

# No Arguments
#
# Returns: <i>Array</i> of <i>String</i>
#
# Prototype implementation for dumping CSV spreadsheet with current voting
# results, returns an array of the lines of text to write to the spreadsheet
# file.

  def tabulator_spreadsheet()
    notfirst = false
    contest_votes = self.counts_contests.keys.sort.collect do |k|
      v = self.counts_contests[k]
      header = (notfirst ? ["","","",""] :
                notfirst = ["CONTEST", "undervote","overvote","write-in"]) +
        v["candidate_count_list"].collect { |cc| cc["candidate_ident"] }
      data = [k, v["undervote_count"],v["overvote_count"],v["writein_count"]] +
        v["candidate_count_list"].collect { |cc| cc["count"] }
      header * "," + "\n" + data * ","
    end
    notfirst = false
    question_votes = self.counts_questions.keys.sort.collect do |k|
      v = self.counts_questions[k]
      header = (notfirst ? ["","",""] :
                notfirst = ["QUESTION", "undervote","overvote"]) +
        v["answer_count_list"].collect { |ac| ac["answer"] }
      data = [k, v["undervote_count"],v["overvote_count"]] +
        v["answer_count_list"].collect { |ac| ac["count"] }
      header * "," + "\n" + data * ","
    end
    (contest_votes * "\n") + "\n\n" + (question_votes * "\n") + "\n\n"
  end

# Arguments:
# * <i>counter_count</i>: (<i>Hash</i>) Counter Count
#
# Returns: N/A
#
# Requires that the Counter Count had previously undergone validation, but not
# that it had passed.  Adjusts the Tabulator Count auditing information for
# the new Counter Count file, adds the Counter Count to the list of Counter
# Counts held by the Tabulator, and then checks the Counter Count to see if it
# had passed the validation tests, as indicated by the absence of errors in
# its error_list component.  If it passed, its votes are gathered and counted
# and added to the current Tabulator dataset.

  def update_tabulator_count(counter_count)
    ccinfo = counter_count["counter_count"]
    cid = ccinfo["counter_ident"].to_s
    rg = ccinfo["reporting_group"].to_s
    pid = ccinfo["precinct_ident"].to_s
    fid = ccinfo["audit_header"]["file_ident"].to_s
    tc = self.tabulator_count["tabulator_count"]
    at = tc["audit_header"]
    if (at.keys.include?("provenance"))
      at["provenance"].push(fid)
    else
      at["provenance"] = [fid]
    end
    tc["counter_count_list"].push(counter_count)
    if (counter_count['error_list'].length == 0)
      votes_gather(counter_count)
    end
  end

# Arguments:
# * <i>counter_count</i>: (<i>Hash</i>) Counter Count
#
# Returns: N/A
#
# The <tt><b>counts_contests</b></tt> and <tt><b>counts_questions</b></tt>
# attributes hold the current vote counts for all Contests and Questions.
# This method updates this voting information with the new votes held in the
# (previously validated) Counter Count provided as input.  These updates have
# the side effect of updating the current Tabulator Count data structure,
# because these counts attributes are actually a part of its data structure.

  private
  def votes_gather(counter_count)
    counter_count["counter_count"]["contest_count_list"].each do |cc|
      conid = cc["contest_ident"]
      votes_incr_contest_overvote(conid, cc["overvote_count"])
      votes_incr_contest_undervote(conid, cc["undervote_count"])
      votes_incr_contest_writeinvote(conid, cc["writein_count"])
      cc["candidate_count_list"].each do |cancount|
        votes_incr_contest_candidate_count(conid,cancount["candidate_ident"],
                                           cancount["count"])
      end
    end
    counter_count["counter_count"]["question_count_list"].each do |qc|
      qid = qc["question_ident"]
      votes_incr_question_overvote(qid, qc["overvote_count"])
      votes_incr_question_undervote(qid, qc["undervote_count"])
      qc["answer_count_list"].each do |anscount|
        votes_incr_question_answer_count(qid,anscount["answer"],
                                         anscount["count"])
      end
    end
  end

# Arguments:
# * <i>conid</i>: (<i>String</i>) Contest UID
# * <i>nvotes</i>: (<i>Integer</i>) number of votes to increment
#
# Returns: N/A
#
# Increments, by <i>nvotes</i>, the overvote count for the specified Contest.

  def votes_incr_contest_overvote(conid, nvotes)
    return if nvotes == 0
    type = "overvote_count"
    shouldnt("No such vote type (#{type}) for Contest: #{conid}\n") unless
      self.counts_contests[conid].key?(type)
    self.counts_contests[conid][type] += nvotes
  end

# Arguments:
# * <i>conid</i>: (<i>String</i>) Contest UID
# * <i>nvotes</i>: (<i>Integer</i>) number of votes to increment
#
# Returns: N/A
#
# Increments, by <i>nvotes</i>, the undervote count for the specified Contest.

  def votes_incr_contest_undervote(conid, nvotes)
    return if nvotes == 0
    type = "undervote_count"
    shouldnt("No such vote type (#{type}) for Contest: #{conid}\n") unless
      self.counts_contests[conid].key?(type)
    self.counts_contests[conid][type] += nvotes
  end

# Arguments:
# * <i>conid</i>: (<i>String</i>) Contest UID
# * <i>nvotes</i>: (<i>Integer</i>) number of votes to increment
#
# Returns: N/A
#
# Increments, by <i>nvotes</i>, the write-in vote count for the specified Contest.

  def votes_incr_contest_writeinvote(conid, nvotes)
    return if nvotes == 0
    type = "writein_count"
    shouldnt("No such vote type (#{type}) for Contest: #{conid}\n") unless
      self.counts_contests[conid].key?(type)
    self.counts_contests[conid][type] += nvotes
  end

# Arguments:
# * <i>conid</i>: (<i>String</i>) Contest UID
# * <i>canid</i>: (<i>String</i>) Candidate UID
# * <i>nvotes</i>: (<i>Integer</i>) number of votes to increment
#
# Returns: N/A
#
# Increments, by <i>nvotes</i>, the count of the Candidate for the specified
# Contest.

  def votes_incr_contest_candidate_count(conid, canid, nvotes)
    return if nvotes == 0
    self.counts_contests[conid]["candidate_count_list"].each do |cc|
      if (cc["candidate_ident"] == canid)
        cc["count"] += nvotes
        return
      end
    end
    shoudnt("No such Candidate (#{canid}) for Contest: #{conid}\n")
  end

# Arguments:
# * <i>qid</i>: (<i>String</i>) Question UID
# * <i>nvotes</i>: (<i>Integer</i>) number of votes to increment
#
# Returns: N/A
#
# Increments, by <i>nvotes</i>, the overvote count for the specified Question.

  def votes_incr_question_overvote(qid, nvotes)
    return if nvotes == 0
    type = "overvote_count"
    shouldnt("No such vote type (#{type}) for Question: #{qid}\n") unless
      self.counts_questions[qid].key?(type)
    self.counts_questions[qid][type] += nvotes
  end

# Arguments:
# * <i>qid</i>: (<i>String</i>) Question UID
# * <i>nvotes</i>: (<i>Integer</i>) number of votes to increment
#
# Returns: N/A
#
# Increments, by <i>nvotes</i>, the undervote count for the specified Question.

  def votes_incr_question_undervote(qid, nvotes)
    return if nvotes == 0
    type = "undervote_count"
    shouldnt("No such vote type (#{type}) for Question: #{qid}\n") unless
      self.counts_questions[qid].key?(type)
    self.counts_questions[qid][type] += nvotes
  end

# Arguments:
# * <i>qid</i>: (<i>String</i>) Question UID
# * <i>answer</i>: (<i>String</i>) Answer
# * <i>nvotes</i>: (<i>Integer</i>) number of votes to increment
#
# Returns: N/A
#
# Increments, by <i>nvotes</i>, the count of the Answer to the specified Question.

  def votes_incr_question_answer_count(qid, answer, nvotes)
    return if nvotes == 0
    self.counts_questions[qid]["answer_count_list"].each do |cc|
      if (cc["answer"] == answer)
        cc["count"] += nvotes
        return
      end
    end
    shoudnt("No such Answer (#{answer}) for Question: #{qid}")
  end

end
