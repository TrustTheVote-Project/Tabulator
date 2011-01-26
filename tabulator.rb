require "yaml"

class UidErr < Exception
  def initialize(tag, mesg)
    print "\n**#{tag} ERROR** #{mesg}\n\n"
  end
end

class ShouldntErr < Exception
  def initialize(mesg)
    print "\n**FATAL ERROR SHOULD NOT HAPPEN (#{tag})**\n**#{mesg}\n\n"
  end
end

$tc_warnings = []

def tab_warn(tag, mesg)
  warning = "**#{tag} WARNING** #{mesg}"
  unless ($tc_warnings.include?(warning))
    print "\n#{warning}"
    $tc_warnings.push(warning)
  end
end

def tabulator_warnings
  $tc_warnings
end

def tabulator_warnings_reset
  $tc_warnings = []
end

def tabulator_count_file
  'TABULATOR_COUNT.yml'
end

def tabulator_csv_file
  'TABULATOR_COUNT.csv'
end

def tabulator_state
  (File.exists?(tabulator_count_file()) ?
   "ACCUMULATING (Waiting for Counter Data)" :
   "INITIAL (Waiting for Election Definition)")
end

def tabulator_initaliaze
  $unique_ids = Hash.new { |h,k| h[k] = [] }
  $expected_counts = Hash.new { |h,k| h[k] = [] }
  $contest_count_info = Hash.new { |h,k| h[k] = {} }
  $question_count_info = Hash.new { |h,k| h[k] = {} }
end

def tab_incr_contest_xvote(conid, id, n)
  unless $contest_count_info[conid].key?(id)
    raise ShouldntErr.new("No such vote type (#{id}) for Contest ID: #{conid}\n")
  end
  $contest_count_info[conid][id] += n
end

def tab_incr_contest_candidate_count(conid, canid, n)
  $contest_count_info[conid]['candidate_count_list'].each do |cc|
    if (cc['candidate_ident'] == canid)
      cc['count'] += n
      return
    end
  end
  raise ShouldntErr.new("No such Candidate ID (#{canid}) for Contest ID: #{conid}\n")
end

def tab_incr_question_xvote(qid, id, n)
  unless $question_count_info[qid].key?(id)
    raise ShouldntErr.new("No such vote type (#{id}) for Question ID: #{qid}\n")
  end
  $question_count_info[qid][id] += n
end

def tab_incr_question_answer_count(qid, aid, n)
  $question_count_info[qid]['answer_count_list'].each do |cc|
    if (cc['answer'] == aid)
      cc['count'] += n
      return
    end
  end
  raise ShouldntErr.new("No such Answer ID (#{aid}) for Question ID: #{qid}\n")
end

def tabulator_validate_election_definition(edinfo)
  tab_new_uid_check2('election',edinfo['election']['ident'])
  if (edinfo['election']['reporting_group_list'].is_a?(Array))
    edinfo['election']['reporting_group_list'].each { |group|
      tab_new_uid_check2('reporting group',group,'Reporting Group') }
  end
  edinfo['contest_list'].each { |x|
    tab_new_uid_check('contest',x,'Contest (Ignored)') }
  edinfo['candidate_list'].each { |x|
    tab_new_uid_check('candidate',x,'Candidate (Ignored)') }
  edinfo['question_list'].each { |x|
    tab_new_uid_check('question',x,'Question (Ignored)') }
  edinfo['counter_list'].each { |x|
    tab_new_uid_check('counter',x,'Counter (Ignored)') }
  edinfo['expected_count_list'].each do |ecount|
    cid = ecount['counter_ident']
    tab_warn('ED',"Expected Count has unrecognized Counter: #{cid}") unless tab_uid_exists?('counter', cid)
    rg = ecount['reporting_group']
    tab_warn('ED',"Expected Count for #{cid} has unrecognized reporting group: #{rg}") unless tab_uid_exists?('reporting group',rg)
    ecount['precinct_ident_list'].each do |pid|
      tab_warn('ED',"Expected Count for #{cid} has invalid precinct: #{pid}") unless tab_uid_exists?('precinct', pid)
      if ($expected_counts[cid].is_a?(Hash))
        $expected_counts[cid][rg] = ecount['precinct_ident_list']
      else
        $expected_counts[cid] = {rg=>ecount['precinct_ident_list']}
      end
    end
  end
  edinfo['contest_list'].each do |contest|
    conid = contest['ident']
    did = contest['district_ident']
    tab_check_district_id(did, conid, 'Contest')
    $contest_count_info[conid]['contest_ident'] = conid
    $contest_count_info[conid]['overvote_count'] = 0
    $contest_count_info[conid]['undervote_count'] = 0
    $contest_count_info[conid]['writein_count'] = 0
    $contest_count_info[conid]['candidate_count_list'] = []
  end
  edinfo['candidate_list'].each do |candidate|
    canid = candidate['ident']
    conid = candidate['contest_ident']
    tab_check_candidate_contest_id(canid,conid)
     $contest_count_info[conid]['candidate_count_list'].push({"candidate_ident"=>canid, "count"=>0})
  end
  edinfo['question_list'].each do |question|
    qid = question['ident']
    did = question['district_ident']
    tab_check_district_id(did, qid, 'Question')
    tab_check_duplicated_answer(question['answer_list'], qid)
    $question_count_info[qid]['question_ident'] = qid
    $question_count_info[qid]['overvote_count'] = 0
    $question_count_info[qid]['undervote_count'] = 0
    $question_count_info[qid]['answer_count_list'] = 
      question['answer_list'].collect {|ans| {"answer"=> ans,"count"=> 0}}
  end
end

def tabulator_validate_jurisdiction_definition(jdinfo)
  tab_new_uid_check2('jurisdiction',jdinfo['ident'])
  jdinfo['district_list'].each { |x|
    tab_new_uid_check('district',x,'District (Ignored)') }
  jdinfo['precinct_list'].each { |x|
    tab_new_uid_check('precinct',x,'Precinct (Ignored)') }
end

def tab_check_precinct_id(pid)
  raise UidErr.new('ED',"Non-existent Expected Count Precinct: #{pid}") unless
    tab_uid_exists?('precinct',pid)
end

def tab_check_candidate_contest_id(canid, conid)
  raise UidErr.new('ED',"Non-existent Contest (#{conid}) for Candidate: #{canid}") unless
    tab_uid_exists?('contest',conid)
end

def tab_check_district_id(did, cid, tag)
  raise UidErr.new('ED',"Non-existent #{tag} (#{cid}) District: #{did}") unless
    tab_uid_exists?('district',did)
end

def tab_check_duplicated_answer(answer_list, qid)
  unique_answer_list = answer_list.uniq
  return true if unique_answer_list.length == answer_list.length
  raise UidErr.new('ED',"Duplicated Answer for Question: #{qid}")
end  

def tab_new_uid_check(name, obj, text = '')
  tab_new_uid_check2(name, obj['ident'], text)
end

def tab_new_uid_check2(name, uid, text = '')
  if ( tab_uid_exists?(name, uid) )
    (text == '' ?
     (raise UidErr.new('ED',"Non-unique #{name.capitalize}: #{uid}")) :
     (tab_warn('ED',"Duplicate #{text}: #{uid}")))
  else
    $unique_ids[name].push(uid.to_s)
  end
end

def tab_uid_exists?(name, uid)
  #print "tab_uid_exists? name: #{name} uid: #{uid}\n\n"
  return $unique_ids[name].include?(uid.to_s)
end

def tab_check_uid(tag, name, uid) # Invalid if Non-existent
  raise UidErr.new(tag,"Invalid #{name.capitalize}: #{uid}") unless
    tab_uid_exists?(name,uid)
end

def tab_check_contest_count_item(count_info, conid, canid, existing)
  raise UidErr.new('CC',"Invalid Contest (#{conid}) Candidate: #{canid}") unless
    tab_uid_exists?('candidate',canid)
  raise UidErr.new('CC',"Duplicate Contest (#{conid}) Candidate: #{canid}") if
    existing.include?(canid.to_s)
  raise UidErr.new('CC',"Improper Contest (#{conid}) Candidate: #{canid}") unless
    tab_check_contest_candidate(count_info[conid]['candidate_count_list'], canid)
end

def tab_check_contest_count_items(count_info, ids, uid) # Not all present
  if (ids.length != count_info[uid]['candidate_count_list'].length)
      unids = count_info[uid]['candidate_count_list'] - ids
      unids = unids.inspect.sub(/\[\"/,'(').sub(/\"\]/,')').gsub(/\"/,'')
    raise UidErr.new('CC',"Not all Candidates #{unids} appear in Contest: #{uid}") 
  end
end

def tab_check_contest_candidate(candidate_count_list, canid)
  candidate_count_list.each do |candidate_count|
    return true if candidate_count['candidate_ident'] == canid
  end
  return false
end

def tab_check_question_count_item(count_info, qid, answer, existing)
  raise UidErr.new('CC',"Duplicate Question (#{qid}) Answer: #{answer}") if
    existing.include?(answer.to_s)
  raise UidErr.new('CC',"Improper Question (#{qid}) Answer: #{canid}") unless
    tab_check_question_answer(count_info[qid]['answer_count_list'], answer)
end

def tab_check_question_count_items(count_info, ids, uid) # Not all present
  if (ids.length != count_info[uid]['answer_count_list'].length)
      unids = count_info[uid]['answer_count_list'] - ids
      unids = unids.inspect.sub(/\[\"/,'(').sub(/\"\]/,')').gsub(/\"/,'')
    raise UidErr.new('CC',"Not all Answers #{unids} appear in Question: #{uid}") 
  end
end

def tab_check_question_answer(answer_count_list, answer)
  answer_count_list.each do |answer_count|
    return true if answer_count['answer'] == answer
  end
  return false
end

def tab_check_contest_id(conid, conids)
  raise UidErr.new('CC',"Invalid Contest: #{conid}") unless
    tab_uid_exists?('contest',conid)
  raise UidErr.new('CC',"Duplicate Contest: #{conid}") if
    conids.include?(conid.to_s)
  true
end

def tab_check_question_id(qid, qids)
  raise UidErr.new('CC',"Invalid Question: #{qid}") unless
    tab_uid_exists?('question',qid)
  raise UidErr.new('CC',"Duplicate Question: #{qid}") if
    qids.include?(qid.to_s)
  true
end

def tab_validate_contest_count(cc, conids)
  conid = cc['contest_ident']
  conids.push(conid.to_s) if tab_check_contest_id(conid, conids)
  canids = []
  cc['candidate_count_list'].each do |cancount|
    canid = cancount['candidate_ident']
    tab_check_contest_count_item($contest_count_info, conid, canid, canids)
    canids.push(canid.to_s)
  end
  tab_check_contest_count_items($contest_count_info, canids, conid)
  conids
end

def tab_validate_question_count(qc, qids)
  qid = qc['question_ident']
  qids.push(qid.to_s) if tab_check_question_id(qid, qids)
  ansids = []
  qc['answer_count_list'].each do |anscount|
    ansid = anscount['answer']
    tab_check_question_count_item($question_count_info, qid, ansid, ansids)
    ansids.push(ansid.to_s)
  end
  tab_check_question_count_items($question_count_info, ansids, qid)
  qids
end

def tab_build_contest_counts
  $contest_count_info.keys.sort.collect { |k| $contest_count_info[k] }
end

def tab_build_question_counts
  $question_count_info.keys.sort.collect { |k| $question_count_info[k] }
end

def tabulator_validate_counter_count(ccval) # counter_count val
  election_id = tab_check_uid('CC', 'election', ccval['election_ident'])
  jurisdiction_id = tab_check_uid('CC', 'jurisdiction', ccval['jurisdiction_ident'])
  precinct_id = tab_check_uid('CC', 'precinct', ccval['precinct_ident'])
  reporting_group = ccval['reporting_group']
  tab_warn('CC',"Unrecognized Reporting Group: #{reporting_group}\n") unless
    tab_uid_exists?('reporting group',reporting_group)
  counter_id = tab_check_uid('CC', 'counter', ccval['counter_ident'])
  conids = []
  ccval['contest_count_list'].each do |cc|
    conids = tab_validate_contest_count(cc, conids)
  end
  qids = []
  ccval['question_count_list'].each do |qc|
    qids = tab_validate_question_count(qc, qids)
  end
end

def tabulator_check_duplicate_counter_count(ccval) # counter_count val
  file_id = ccval['audit_trail']['file_ident']
  raise UidErr.new('CC',"Duplicate Counter Count file: #{file_id}") if
    tab_uid_exists?('file',file_id)
end

def tab_find_count(tc, cid, rg, pid)
  tc['tabulator_count']['counter_count_list'].each do |counter_count|
    counter_count = counter_count['counter_count']
    cid1 = counter_count['counter_ident']
    rg1 = counter_count['reporting_group']
    pid1 = counter_count['precinct_ident']
    return true if ((cid == cid1) && (rg == rg1) && (pid == pid1))
  end
  false
end
  
def tabulator_missing_counts(tc)
  missing = []
  $expected_counts.keys.sort.each do |cid|
    $expected_counts[cid].keys.sort.each do |rg|
      $expected_counts[cid][rg].each do |pid|
        missing.push([cid, rg, pid]) unless tab_find_count(tc, cid, rg, pid)
      end
    end
  end
  missing
end

def tabulator_gather_counter_count_votes(ccval)
  ccval['contest_count_list'].each do |cc|
    conid = cc['contest_ident']
    tab_incr_contest_xvote(conid,'overvote_count',cc['overvote_count'])
    tab_incr_contest_xvote(conid,'undervote_count',cc['undervote_count'])
    tab_incr_contest_xvote(conid,'writein_count',cc['writein_count'])
    cc['candidate_count_list'].each do |cancount|
      tab_incr_contest_candidate_count(conid,
                                       cancount['candidate_ident'],
                                       cancount['count'])
    end
  end
  ccval['question_count_list'].each do |qc|
    qid = qc['question_ident']
    tab_incr_question_xvote(qid,'overvote_count',qc['overvote_count'])
    tab_incr_question_xvote(qid,'undervote_count',qc['undervote_count'])
    qc['answer_count_list'].each do |anscount|
      tab_incr_question_answer_count(qid,anscount['answer'],anscount['count'])
    end
  end
end

def tabulator_validate_tabulator_count(tc)
  tcval = tc['tabulator_count']
  tabulator_validate_jurisdiction_definition(tcval['jurisdiction_definition'])
  tabulator_validate_election_definition(tcval['election_definition'])
  election_id = tab_check_uid('TC', 'election', tcval['election_ident'])
  jurisdiction_id = tab_check_uid('TC','jurisdiction', tcval['jurisdiction_ident'])
  if (tc['tabulator_count']['audit_trail']['provenance'])
    tc['tabulator_count']['audit_trail']['provenance'].each do |fid|
      tab_new_uid_check2('file',fid)
    end
  end
  tc['tabulator_count']['contest_count_list'].each do |cc|
    $contest_count_info[cc['contest_ident']] = cc # check for duplicates
  end
  tc['tabulator_count']['question_count_list'].each do |qc|
    $question_count_info[qc['question_ident']] = qc # check for duplicates
  end
  tc
end

def tabulator_new(jdinfo, edinfo)
  {"tabulator_count"=>
    {"election_ident"=>edinfo['election']['ident'],
      "jurisdiction_ident"=>jdinfo['ident'],
      "audit_trail"=>
      {"software"=>"TTV Tabulator v JVC",
        "file_ident"=>tabulator_count_file(),
        "operator"=>"El Jefe",
        "create_date"=>Time.new.strftime("%Y-%m-%d %H:%M:%S"),
      },
      "jurisdiction_definition"=>jdinfo,
      "election_definition"=>edinfo,
      "contest_count_list"=>tab_build_contest_counts(),
      "question_count_list"=>tab_build_question_counts(),
                      "counter_count_list"=>[]}}
end

def tabulator_update(tc, cc)
  fid = cc['counter_count']['audit_trail']['file_ident']
  at = tc['tabulator_count']['audit_trail']
  (at['provenance'] ? at['provenance'].push(fid.to_s) : at['provenance'] = [fid])
  tc['tabulator_count']['counter_count_list'].push(cc)
  tc
end

def tabulator_spreadsheet
  info = $contest_count_info.collect do |k, v|
    [['CONTEST', 'undervote_count','overvote_count','writein_count'] +
     v['candidate_count_list'].collect { |id| id },
     [k, v['undervote_count'],v['overvote_count'],
     ($contest_count_info[k]['type'] == 'contest' ? v['writein_count'] : 0 )] +
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

def tabulator_dump_data(datum = false)
  print YAML::dump(datum),"\n" if datum
  print "Dumping Data Structures\n"
  $unique_ids.sort.each do |k, v|
    print "  ",k.capitalize," IDs: ",v.inspect.gsub(/\"/,''),"\n"
  end
  print "  Expected Counts:\n"
  $expected_counts.keys.sort.each do |cid|
    $expected_counts[cid].keys.sort.each do |rg|
      pids = $expected_counts[cid][rg]
      print "    #{cid} #{rg} #{pids.inspect.gsub(/\"/,'')}\n"
    end
  end
  print "  Contest Info:\n"
  $contest_count_info.sort.each do |k, v|
    print "    #{k}:\n"
    print "      overvote = #{v['overvote_count']}, "
    print "undervote = #{v['undervote_count']}, "
    print "writeins = #{v['writein_count']}\n"
    v['candidate_count_list'].each do |item|
      print "      #{item['candidate_ident']} = #{item['count']}\n"
    end
  end
  print "  Question Info:\n"
  $question_count_info.sort.each do |k, v|
    print "    #{k}:\n"
    print "      overvote = #{v['overvote_count']}, "
    print "undervote = #{v['undervote_count']}\n"
    v['answer_count_list'].each do |item|
      print "      #{item['answer']} = #{item['count']}\n"
    end
  end
  print "\n"
end
