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
require "validate"

# The Tabulator class inherits the capabilities of the TabulatorValidate
# class, and provides additional functionality for determining the Tabulator
# State, and for counting votes by processing Counter Counts and then updating
# the Tabulator Count.

class Tabulator < TabulatorValidate

# Arguments:
# * <i>tabulator_count</i>: (<i>Hash</i>) Tabulator Count
#
# Returns: <i>Array</i>
#
# Returns an <i>Array</i> whose 1st element is a message string indicating the
# current state of the Tabulator, and whose 2nd element is an <i>Array</i> of
# the Expected Counts that are still missing (let's say there are M of them).
# There are three possible Tabulator states:
# * INITIAL: Waiting for first Counter Count, M Missing
# * ACCUMULATING: Waiting for more Counter Counts, M Missing
# * DONE: All M Expected Counter Counts Accumulated

  def current_tabulator_state(tabulator_count)
    if (tabulator_count.is_a?(Hash) &&
        tabulator_count.keys.include?("tabulator_count"))
      missed = self.counts_missing["missing"].length.to_s
      total = self.counts_missing["total"].to_s
      if (0 == tabulator_count["tabulator_count"]["counter_count_list"].length)
        ["INITIAL (Waiting for first Counter Count, #{missed} Missing)", []]
      elsif (missed == "0")
        ["DONE! (All #{total} Expected Counter Counts Accumulated)", []]
      else
        ["ACCUMULATING (Waiting for more Counter Counts, #{missed} Missing)",
         self.counts_missing["missing"] ]
      end
    else
      shouldnt("Invalid Tabulator Count passed to current_tabulator_state")
    end
  end

# Arguments:
# * <i>tabulator_count</i>: (<i>Hash</i>) Tabulator Count
# * <i>counter_count</i>: (<i>Hash</i>) Counter Count
#
# Returns: N/A
#
# Requires that the Counter Count was previously validated. Adjusts the
# Tabulator Count auditing information for the new Counter Count file, gathers
# the votes from the Counter Count, adds the Counter Count to the list of
# Counter Counts held by the Tabulator, and returns the resulting Tabulator
# Count.

  def update_tabulator_count(tabulator_count, counter_count)
    fid = counter_count["counter_count"]["audit_trail"]["file_ident"].to_s
    at = tabulator_count["tabulator_count"]["audit_trail"]
    if (at.keys.include?("provenance"))
      at["provenance"].push(fid)
    else
      at["provenance"] = [fid]
    end
    votes_gather(counter_count)
    tabulator_count["tabulator_count"]["counter_count_list"].push(counter_count)
    tabulator_count
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

# Prototype implementation only.

  public
  def spreadsheet_for_tabulator()
    info = self.counts_contests.collect do |k, v|
      [["CONTEST", "undervote_count","overvote_count","writein_count"] +
       v["candidate_count_list"].collect { |id| id },
       [k, v["undervote_count"],v["overvote_count"],
        (self.counts_contests[k]["type"] == "contest" ? v["writein_count"] : 0 )] +
       v["candidate_count_list"].collect { |id| v[id] }]
    end
    lastinfo = info.collect do |x|
      str = ""
      x[0].each { |y| str = str + y.inspect + "," }; str = str + "\n"
      x[1].each { |y| str = str + y.inspect + "," }; str = str + "\n"
    end
    str = ""; lastinfo.each { |x| str = str + x }
    str
  end

# Arguments:
# * <i>datum</i>: (<i>Arbitrary</i>), arbitrary datum whose value is dumped 
#
# Returns: N/A
#
# For debugging only.  Prints the values of all of the Tabulator attributes,
# after printing the value of the optional <i>datum</i> provided as an
# argument.

  def dump_tabulator_data(datum = false)
    print "Dumping Data Structures\n"
    print YAML::dump(datum),"\n" if datum
    self.uids.sort.each do |k, v|
      print "  ",k.capitalize," IDs: ",v.inspect.gsub(/\"/,""),"\n"
    end
    count = self.counts_missing["missing"].length
    total = self.counts_missing["total"]
    print "  Expected Counts #{count} #{total} (Counter ID, Reporting Group ID, Precinct IDs):\n"
    self.counts_missing["expected"].keys.sort.each do |cid|
      self.counts_missing["expected"][cid].keys.sort.each do |rg|
        pids = self.counts_missing["expected"][cid][rg].keys
        print "    #{cid} #{rg} #{pids.inspect.gsub(/\"/,"")}\n"
      end
    end
    print "  Contest Info:\n"
    self.counts_contests.keys.sort.each do |k|
      v = self.counts_contests[k]
      print "    #{k}:\n"
      print "      overvote = #{v["overvote_count"]}, "
      print "undervote = #{v["undervote_count"]}, "
      print "writeins = #{v["writein_count"]}\n"
      v["candidate_count_list"].each do |item|
        print "      #{item["candidate_ident"]} = #{item["count"]}\n"
      end
    end
    print "  Question Info:\n"
    self.counts_questions.keys.sort.each do |k|
      v = self.counts_questions[k]
      print "    #{k}:\n"
      print "      overvote = #{v["overvote_count"]}, "
      print "undervote = #{v["undervote_count"]}\n"
      v["answer_count_list"].each do |item|
        print "      #{item["answer"]} = #{item["count"]}\n"
      end
    end
    print "\n"
  end

end
