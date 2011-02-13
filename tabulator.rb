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
# There are four possible Tabulator states, only the last three of which the
# Tabulator is capable of reporting (the Tabulator is in the EMPTY state
# before it is instantiated):
# * EMPTY: Waiting for Jurisdiction and Election Definitions
# * INITIAL: Waiting for 1st Counter Count, M Missing
# * ACCUMULATING: Waiting for Counter Counts, M Missing
# * DONE: All M Expected Counter Counts Accumulated

  def tabulator_state()
    state = self.tabulator_count["tabulator_count"]["state"]
    missed = self.counts_missing["missing"].length.to_s
    total = self.counts_missing["total"].to_s
    count = (total == 1 ? "1 Expected Count" : "#{total.to_s} Expected Counts")
    case state
    when "INITIAL"
      ["INITIAL (Waiting for 1st of #{count})", [], [], 0]
    when "DONE"
      ["DONE (All #{total.to_s} Expected Counts Accumulated)", [], [], 0]
    when "ACCUMULATING"
      ["ACCUMULATING (#{missed} Missing from #{count})",
       self.counts_missing["missing"],
       self.counts_missing["finished"],
       self.counts_missing["expected"].keys.length]
    else
      shouldnt("Invalid Tabulator State: #{state.to_s}")
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

  def update_tabulator_count(counter_count)
    fid = counter_count["counter_count"]["audit_header"]["file_ident"].to_s
    tc = self.tabulator_count["tabulator_count"]
    at = tc["audit_header"]
    if (at.keys.include?("provenance"))
      at["provenance"].push(fid)
    else
      at["provenance"] = [fid]
    end
    votes_gather(counter_count) unless counter_count['error_list'].length > 0
    tc["counter_count_list"].push(counter_count)
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
  def tabulator_spreadsheet()
    notfirst = false
    contest_votes = self.counts_contests.collect do |k, v|
      header = (notfirst ? ["","","",""] :
                notfirst = ["CONTEST", "undervote","overvote","write-in"]) +
        v["candidate_count_list"].collect { |cc| cc["candidate_ident"] }
      data = [k, v["undervote_count"],v["overvote_count"],
              (self.counts_contests[k]["type"] == "contest" ? v["writein"] : 0 )] +
        v["candidate_count_list"].collect { |cc| cc["count"] }
      header * "," + "\n" + data * ","
    end
    notfirst = false
    question_votes = self.counts_questions.collect do |k, v|
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
# * <i>print</i>: (<i>Boolean</i>) whether to print the Tabulator Count (optional)
#
# Returns: N/A
#
# Prints the value of the current Tabulator Count if <i>print</i> is
# <i>true</i>.  Prints the values of all of the Tabulator attributes (internal
# data structures).

  def tabulator_dump_data(print = false)
    print "Tabulator Count\n" if print
    print YAML::dump(self.tabulator_count),"\n" if print
    print "Tabulator Data Summary\n"
    print "  Jurisdiction UID: #{uids['jurisdiction'][0]}\n"
    print "  Election UID: #{uids['election'][0]}\n"
    ['district','precinct','contest','candidate','question','counter',
     'file','reporting group'].each do |k|
      length = self.uids[k].length.to_s
      uids = self.uids[k].sort
      type = (k =~ /^report/ ? "Reporting Groups" : "#{k.capitalize} UIDs")
      if (uids.length == 0)
        prefix = "  #{type} (NONE)\n"
      else
        prefix = "  #{type} (#{uids.length.to_s}): "
        print prefix
        if (uids.length > 10)
          prefix = "    "
          print "\n#{prefix}"
        end
        pp_uids(uids, prefix.length, prefix.length, 78)
      end
    end
    count = self.counts_missing["missing"].length
    total = self.counts_missing["total"]
    if (total == 0)
      print "  Expected Counts (NONE)\n"
    else
      print "  Expected Counts (#{total}): Counter UID, Reporting Group, Precinct UIDs\n"
      self.counts_missing["expected"].keys.sort.each do |cid|
        self.counts_missing["expected"][cid].keys.sort.each do |rg|
          pids = self.counts_missing["expected"][cid][rg].keys
          print "    #{cid}, #{rg}, #{pids.inspect.gsub(/\"/,"")}\n"
        end
      end
    end
    if (count == 0)
      print "  Missing Counts (NONE)\n"
    else
      print "  Missing Counts (#{count}): Counter UID, Precinct UID, Reporting Group\n"
      self.counts_missing["missing"].each do |cid, rg, pid|
        print "    #{cid}, #{pid}, #{rg}\n"
      end
    end
    if (self.counts_contests.keys.length == 0)
      print "  Contests (NONE)\n"
    else
      print "  Contests (",self.counts_contests.keys.length.to_s,"):"
      print " Contest UID: overvote, undervote, write-in, Candidate UIDs\n"
    end
    self.counts_contests.keys.sort.each do |k|
      v = self.counts_contests[k]
      print "    #{k}: "
      print "overvote = #{v["overvote_count"]}, "
      print "undervote = #{v["undervote_count"]}, "
      print "writeins = #{v["writein_count"]}\n"
      v["candidate_count_list"].each do |item|
        print "      #{item["candidate_ident"]} = #{item["count"]}\n"
      end
    end
    if (self.counts_questions.keys.length == 0)
      print "  Questions (NONE)\n"
    else
      print "  Questions (",self.counts_questions.keys.length.to_s,"):"
      print " Question UID: overvote, undervote, Answers\n"
    end
    self.counts_questions.keys.sort.each do |k|
      v = self.counts_questions[k]
      print "    #{k}: "
      print "overvote = #{v["overvote_count"]}, "
      print "undervote = #{v["undervote_count"]}\n"
      v["answer_count_list"].each do |item|
        print "      #{item["answer"]} = #{item["count"]}\n"
      end
    end
    print "\n"
  end

  private
  def pp_uids(uids, start, curr, fill)
    return print("\n") if (uids.length == 0)
    uid = uids.shift
    print (uid = uid + (uids.length == 0 ? "" : ", "))
    curr += uid.length
    if ((uids.length > 0) && (fill <= (curr + uids[0].length)))
      print "\n"
      start.times { |x| print(" ") }
      curr = start
    end
    pp_uids(uids, start, curr, fill)
  end

end
