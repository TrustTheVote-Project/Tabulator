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
# class, and provides additional functionality for creating new Tabulator
# Counts, determining the Tabulator State, and for counting votes by
# processing Counter Counts and then updating the Tabulator Count.

class Tabulator < TabulatorValidate

# Arguments:
# * <i>tabulator_count</i>: (<i>Hash</i>) Tabulator Count
#
# Returns: <i>Array</i>
#
# Returns an <i>Array</i> whose 1st element is a message string indicating the
# current state of the Tabulator, and whose 2nd element is an <i>Array</i> of
# the missing Expected Counts.  MORE DETAIL...Jeff

  def current_state(tabulator_count)
    if (self.unique_ids.keys.include?('jurisdiction'))
      if (self.unique_ids.keys.include?('election'))
        if (tabulator_count.is_a?(Hash))
          tcinfo = tabulator_count['tabulator_count']
          counts = tcinfo['counter_count_list'].length
          if (counts == 0)
            ["PRE-ACCUMULATING (Waiting for Counter Data, None So Far)", []]
          else
            miscounts = missing_expected_counts(tabulator_count)
            m = miscounts.length 
            if (m == 0)
              ["DONE! (All Expected Counts Present)", []]
            else
              ["ACCUMULATING (Waiting for Data, #{m.to_s} Missing Counts)",
               miscounts]
            end
          end
        else
          ["UNKNOWN (Invalid Tabulator Count)", []]
        end
      else
        ["INITIAL (Waiting for an Election Definition)", []]
      end
    else
      ["INITIAL (Waiting for a Jurisdiction Definition)", []]
    end
  end

# Arguments:
# * <i>jurisdiction_definition</i>: (<i>Hash</i>) Jurisdiction Definition
# * <i>election_definition</i>: (<i>Hash</i>) Election Definition
# * <i>file</i>:   (<i>String</i>) File name to store Tabulator Count
#
# Returns: <i>Hash</i>
#
# Returns a initial Tabulator Count constructed from the information provided
# in the Jurisdiction Definition, Election Definition, and File.  Uses the
# side effects (initialization of the <i>counter_counts</i> and
# <i>question_counts</i> attributes) of the previous validation of the
# Election Definition to create and insert zero-initialized Contest and
# Question Counts.

  def create_tabulator_count(jurisdiction_definition, election_definition, file)
    jdinfo = jurisdiction_definition['jurisdiction_definition']
    edinfo = election_definition['election_definition']
    {"tabulator_count"=>
      {"election_ident"=>edinfo['election']['ident'],
        "jurisdiction_ident"=>jdinfo['ident'],
        "audit_trail"=>
        {"software"=>"TTV Tabulator v JVC",
          "file_ident"=>file,
          "operator"=>"El Jefe",
          "create_date"=>Time.new.strftime("%Y-%m-%d %H:%M:%S"),
        },
        "jurisdiction_definition"=>jdinfo,
        "election_definition"=>edinfo,
        "contest_count_list"=>self.contest_counts.keys.collect { |k|
          self.contest_counts[k] },
        "question_count_list"=>self.question_counts.keys.collect { |k|
          self.question_counts[k] },
        "counter_count_list"=>[]}}
  end

# Arguments:
# * <i>tabulator_count</i>: (<i>Hash</i>) Tabulator Count
# * <i>counter_count</i>: (<i>Hash</i>) Counter Count
#
# Returns: N/A
#
# Adjusts the Tabulator auditing information for the new Counter Count file,
# gathers the votes from the Counter Count, adds the Counter Count to the list
# of Counter Counts held by the Tabulator, and returns the resulting Tabulator
# Count.

  def update_tabulator_count(tabulator_count, counter_count)
    fid = counter_count['counter_count']['audit_trail']['file_ident'].to_s
    at = tabulator_count['tabulator_count']['audit_trail']
    if (at.keys.include?('provenance'))
      at['provenance'].push(fid)
    else
      at['provenance'] = [fid]
    end
    votes_gather(counter_count)
    tabulator_count['tabulator_count']['counter_count_list'].push(counter_count)
    tabulator_count
  end

# Arguments:
# * <i>tabulator_count</i>: (<i>Hash</i>) Tabulator Count
#
# Returns: <i>Array</i> of <i>Array</i>
#
# Returns an <i>Array</i> of the Expected Counts missing from the Tabulator
# Count. The length of the <i>Array</i> indicates the number of missing counts
# and each sub-<i>Array</i> holds the Counter UID, Reporting Group, and
# Precinct UID for a missing count.

  private
  def missing_expected_counts(tabulator_count)
    tcinfo = tabulator_count['tabulator_count']
    missing = []
    self.expected_counts.keys.sort.each do |cid|
      self.expected_counts[cid].keys.sort.each do |rg|
        self.expected_counts[cid][rg].each do |pid|
          missing.push([cid, rg, pid]) unless
            missing_found?(tcinfo, cid, rg, pid)
        end
      end
    end
    missing
  end

# Arguments:
# * <i>tcinfo</i>: (<i>Hash</i>) Tabulator Count information
# * <i>cid</i>:    (<i>String</i>) Counter UID
# * <i>rg</i>:     (<i>String</i>) Reporting Group name
# * <i>pid</i>:    (<i>String</i>) Precinct UID
#
# Returns: <i>Boolean</i>
#
# Returns <i>true</i> if a Counter Count, that contains the Counter UID,
# Reporting Group name, and Precinct UID passed as arguments, appears in the
# Tabulator Count, returns <i>false</i> otherwise.

  def missing_found?(tcinfo, cid, rg, pid)
    tcinfo['counter_count_list'].each do |counter_count|
      counter_count = counter_count['counter_count']
      cid1 = counter_count['counter_ident']
      rg1 = counter_count['reporting_group']
      pid1 = counter_count['precinct_ident']
      return true if ((cid == cid1) && (rg == rg1) && (pid == pid1))
    end
    false
  end
  
# Arguments:
# * <i>counter_count</i>: (<i>Hash</i>) Counter Count
#
# Returns: N/A
#
# The <i>contest_counts</i> and <i>question_counts</i> attributes hold the
# current vote counts for all Contests and Questions.  This method updates
# this voting information with the new votes held in the Counter Count
# provided as input.  
#
# This method has the side effect of updating the contents of the current
# Tabulator Count data structure, because of the nature of the information
# held by the two counts attributes.

  def votes_gather(counter_count)
    counter_count['counter_count']['contest_count_list'].each do |cc|
      conid = cc['contest_ident']
      votes_incr_contest_overvote(conid, cc['overvote_count'])
      votes_incr_contest_undervote(conid, cc['undervote_count'])
      votes_incr_contest_writeinvote(conid, cc['writein_count'])
      cc['candidate_count_list'].each do |cancount|
        votes_incr_contest_candidate_count(conid,cancount['candidate_ident'],
                                           cancount['count'])
      end
    end
    counter_count['counter_count']['question_count_list'].each do |qc|
      qid = qc['question_ident']
      votes_incr_question_overvote(qid, qc['overvote_count'])
      votes_incr_question_undervote(qid, qc['undervote_count'])
      qc['answer_count_list'].each do |anscount|
        votes_incr_question_answer_count(qid,anscount['answer'],
                                         anscount['count'])
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
    type = 'overvote_count'
    shouldnt("No such vote type (#{type}) for Contest: #{conid}\n") unless
      self.contest_counts[conid].key?(type)
    self.contest_counts[conid][type] += nvotes
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
    type = 'undervote_count'
    shouldnt("No such vote type (#{type}) for Contest: #{conid}\n") unless
      self.contest_counts[conid].key?(type)
    self.contest_counts[conid][type] += nvotes
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
    type = 'writein_count'
    shouldnt("No such vote type (#{type}) for Contest: #{conid}\n") unless
      self.contest_counts[conid].key?(type)
    self.contest_counts[conid][type] += nvotes
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
    self.contest_counts[conid]['candidate_count_list'].each do |cc|
      if (cc['candidate_ident'] == canid)
        cc['count'] += nvotes
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
    type = 'overvote_count'
    shouldnt("No such vote type (#{type}) for Question: #{qid}\n") unless
      self.question_counts[qid].key?(type)
    self.question_counts[qid][type] += nvotes
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
    type = 'undervote_count'
    shouldnt("No such vote type (#{type}) for Question: #{qid}\n") unless
      self.question_counts[qid].key?(type)
    self.question_counts[qid][type] += nvotes
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
    self.question_counts[qid]['answer_count_list'].each do |cc|
      if (cc['answer'] == answer)
        cc['count'] += nvotes
        return
      end
    end
    shoudnt("No such Answer (#{answer}) for Question: #{qid}")
  end

# Prototype implementation only.

  public
  def create_tabulator_spreadsheet
    info = self.contest_counts.collect do |k, v|
      [['CONTEST', 'undervote_count','overvote_count','writein_count'] +
       v['candidate_count_list'].collect { |id| id },
       [k, v['undervote_count'],v['overvote_count'],
        (self.contest_counts[k]['type'] == 'contest' ? v['writein_count'] : 0 )] +
       v['candidate_count_list'].collect { |id| v[id] }]
    end
    lastinfo = info.collect do |x|
      str = ''
      x[0].each { |y| str = str + y.inspect + "," }; str = str + "\n"
      x[1].each { |y| str = str + y.inspect + "," }; str = str + "\n"
    end
    str = ''; lastinfo.each { |x| str = str + x }
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
    self.unique_ids.sort.each do |k, v|
      print "  ",k.capitalize," IDs: ",v.inspect.gsub(/\"/,""),"\n"
    end
    print "  Expected Counts (Counter ID, Reporting Group ID, Precinct IDs):\n"
    self.expected_counts.keys.sort.each do |cid|
      self.expected_counts[cid].keys.sort.each do |rgid|
        pids = self.expected_counts[cid][rgid]
        print "    #{cid} #{rgid} #{pids.inspect.gsub(/\"/,"")}\n"
      end
    end
    print "  Contest Info:\n"
    self.contest_counts.keys.sort.each do |k|
      v = self.contest_counts[k]
      print "    #{k}:\n"
      print "      overvote = #{v["overvote_count"]}, "
      print "undervote = #{v["undervote_count"]}, "
      print "writeins = #{v["writein_count"]}\n"
      v["candidate_count_list"].each do |item|
        print "      #{item["candidate_ident"]} = #{item["count"]}\n"
      end
    end
    print "  Question Info:\n"
    self.question_counts.keys.sort.each do |k|
      v = self.question_counts[k]
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
