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
  $precinct_distids = Hash.new { |h,k| h[k] = [] }
  $precinct_counts = Hash.new { |h,k| h[k] = {} }
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
      tab_new_uid_check2('reporting_group',group,'Reporting Group') }
  end
  tab_new_uid_check('jurisdiction',edinfo)
  edinfo['district_list'].each { |x|
    tab_new_uid_check('district',x,'District (Ignored)') }
  edinfo['precinct_list'].each { |x|
    tab_new_uid_check('precinct',x,'Precinct (Ignored)') }
  edinfo['contest_list'].each { |x|
    tab_new_uid_check('contest',x,'Contest (Ignored)') }
  edinfo['candidate_list'].each { |x|
    tab_new_uid_check('candidate',x,'Candidate (Ignored)') }
  edinfo['question_list'].each { |x|
    tab_new_uid_check('question',x,'Question (Ignored)') }
  edinfo['counter_list'].each { |x|
    tab_new_uid_check('counter',x,'Counter (Ignored)') }
  allcids = []
  edinfo['precount_list'].each do |precinct|
    pid = precinct['ident']
    tab_check_precinct_id(pid)
    $precinct_distids[pid] = []
    precinct['district_ident_list'].each do |uid|
      tab_new_precinct_district(pid,uid,'District','district')
    end
    cids = []
    precinct['expected_count_list'].each do |ecval|
      cid = ecval['counter_ident']
      tab_warn('ED',"Precinct (#{pid}) has unexpected Counter: #{cid}") unless
        tab_uid_exists?('counter',cid)
      tab_warn('ED',"Precinct (#{pid}) has duplicate expected Counter: #{cid}") if
        cids.include?(cid.to_s)
      $precinct_counts[pid][cid] = ecval['count']
      cids.push(cid.to_s)
      allcids.push(cid.to_s) unless allcids.include?(cid.to_s)
    end
  end
  if (allcids.length != $unique_ids['counter'].length)
    allcids = $unique_ids['counter'] - allcids
    allcids = allcids.inspect.sub(/\[\"/,'(').sub(/\"\]/,')').gsub(/\"/,'')
    tab_warn('ED',"Not all Counters #{allcids} expected by listed Precincts")
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
    $question_count_info[qid]['question_ident'] = qid
    $question_count_info[qid]['overvote_count'] = 0
    $question_count_info[qid]['undervote_count'] = 0
    $question_count_info[qid]['answer_count_list'] = 
      question['answer_list'].collect {|ans| {"answer"=> ans,"count"=> 0}}
  end
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

def tab_new_uid_check(name, obj, text = '')
  if (obj.key?(name) && name != "question")
    tab_new_uid_check2(name, obj[name]['ident'], text)
  else
    tab_new_uid_check2(name, obj['ident'], text)
  end
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

def tab_check_subid(sublist, name, uid, subid, text, subname) # Duplicate, Non-existent
  if ( sublist.include?(subid.to_s) )
    raise UidErr.new('ED',"Duplicate #{name} (#{uid}) #{text}: #{subid}")
  elsif ( subname != '' && ! tab_uid_exists?(subname,subid) )
    subname = subname.capitalize
    raise UidErr.new('ED',"Non-existent #{name} (#{uid}) #{subname}: #{subid}")
  end
end

def tab_new_precinct_district(uid, subid, text, subname = '')
  tab_check_subid($precinct_distids[uid],'Precinct',uid,subid,text,subname)
  $precinct_distids[uid].push(subid.to_s)
end

def tab_uid_exists?(name, uid)
  #print "tab_uid_exists? name: #{name} uid: #{uid}\n\n"
  return $unique_ids[name].include?(uid.to_s)
end

def tab_check_uid(tag, name, uid) # Invalid if Non-existent
  raise UidErr.new(tag,"Invalid #{name.capitalize}: #{uid}") unless
    tab_uid_exists?(name,uid)
end

def tab_check_contest_count_items(count_info, ids, uid, text) # Not all present
  if (ids.length != count_info[uid]['candidate_count_list'].length)
      unids = count_info[uid]['candidate_count_list'] - ids
      unids = unids.inspect.sub(/\[\"/,'(').sub(/\"\]/,')').gsub(/\"/,'')
    raise UidErr.new('CC',"Not all #{text} #{unids} appear in Contest: #{uid}") 
  end
end

def tab_check_question_count_items(count_info, ids, uid, text) # Not all present
  if (ids.length != count_info[uid]['answer_count_list'].length)
      unids = count_info[uid]['answer_count_list'] - ids
      unids = unids.inspect.sub(/\[\"/,'(').sub(/\"\]/,')').gsub(/\"/,'')
    raise UidErr.new('CC',"Not all #{text} #{unids} appear in Contest: #{uid}") 
  end
end

def tab_check_contest_count_item(count_info, conid, id, existing, text) # Invalid, Improper, Duplicate
  if (text == 'Candidate')
    raise UidErr.new('CC',"Invalid Contest (#{conid}) Candidate: #{id}") unless
      tab_uid_exists?('candidate',id)
  end
  # JVC raise UidErr.new('CC',"Improper Contest (#{conid}) #{text}: #{id}") unless
  #  count_info[conid]['candidate_count_list'].include?(id.to_s)
  raise UidErr.new('CC',"Duplicate Contest (#{conid}) #{text}: #{id}") if
    existing.include?(id.to_s)
end

def tab_check_question_count_item(count_info, conid, id, existing, text) # Invalid, Improper, Duplicate
  if (text == 'Candidate')
    raise UidErr.new('CC',"Invalid Contest (#{conid}) Candidate: #{id}") unless
      tab_uid_exists?('candidate',id)
  end
  # JVC raise UidErr.new('CC',"Improper Contest (#{conid}) #{text}: #{id}") unless
  # JVC  count_info[conid]['answer_count_list'].include?(id.to_s)
  raise UidErr.new('CC',"Duplicate Contest (#{conid}) #{text}: #{id}") if
    existing.include?(id.to_s)
end

def tab_check_contest_id(conid, conids)
  #print "CONid: #{conid} CONids: #{conids.to_s}\n"
  raise UidErr.new('CC',"Invalid Contest: #{conid}") unless
    tab_uid_exists?('contest',conid)
  raise UidErr.new('CC',"Duplicate Contest: #{conid}") if
    conids.include?(conid.to_s)
  true
end

def tab_check_question_id(conid, conids)
  raise UidErr.new('CC',"Invalid Question: #{conid}") unless
    tab_uid_exists?('question',conid)
  raise UidErr.new('CC',"Duplicate Question: #{conid}") if
    conids.include?(conid.to_s)
  true
end

def tab_validate_contest_count(cc, conids)
  conid = cc['contest_ident']
  conids.push(conid.to_s) if tab_check_contest_id(conid, conids)
  canids = []
  cc['candidate_count_list'].each do |cancount|
    canid = cancount['candidate_ident']
    tab_check_contest_count_item($contest_count_info, conid, canid, canids, 'Candidate')
    canids.push(canid.to_s)
  end
  tab_check_contest_count_items($contest_count_info, canids, conid,'Candidates')
  conids
end

def tab_validate_question_count(qc, qids)
  qid = qc['question_ident']
  qids.push(qid.to_s) if tab_check_question_id(qid, qids)
  ansids = []
  qc['answer_count_list'].each do |anscount|
    ansid = anscount['answer']
    tab_check_question_count_item($question_count_info, qid, ansid, ansids, 'Answer')
    ansids.push(ansid.to_s)
  end
  tab_check_question_count_items($question_count_info, ansids, qid, 'Answer')
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
    tab_uid_exists?('reporting_group',reporting_group)
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

def tabulator_accumulated_counter_counts(tc)
  accumulated_counts = {}
  accumulated_conids = []
  tc['tabulator_count']['counter_count_list'].each do |counter_count|
    counter_count = counter_count['counter_count']
    pid = counter_count['precinct_ident']
    accumulated_counts[pid] = {} unless accumulated_counts.key?(pid)
    cid = counter_count['counter_ident']
    if (accumulated_counts[pid].key?(cid))
      accumulated_counts[pid][cid] += 1
    else
      accumulated_counts[pid][cid] = 1
    end
    counter_count['contest_count_list'].each do |cc|
      conid = cc['contest_ident']
      accumulated_conids.push(conid.to_s) unless
        accumulated_conids.include?(conid.to_s)
    end
    counter_count['question_count_list'].each do |qc|
      qid = qc['question_ident']
      accumulated_conids.push(qid.to_s) unless
        accumulated_conids.include?(qid.to_s)
    end
  end
  [accumulated_counts, $unique_ids['contest'] - accumulated_conids]
end

def tabulator_validate_tabulator_count(tc)
  tcval = tc['tabulator_count']
  tabulator_validate_election_definition(tcval['election_definition'])
  election_id = tab_check_uid('TC', 'election', tcval['election_ident'])
  jurisdiction_id = tab_check_uid('TC','jurisdiction', tcval['jurisdiction_ident'])
  if (tc['tabulator_count']['audit_trail']['provenance'])
    tc['tabulator_count']['audit_trail']['provenance'].each do |fid|
      tab_new_uid_check2('file',fid)
    end
  end
  tc['tabulator_count']['contest_count_list'].each do |cc|
    $contest_count_info[cc['contest_ident']] = cc
  end
  tc['tabulator_count']['question_count_list'].each do |qc|
    $question_count_info[qc['question_ident']] = qc
  end
  tc
end

def tabulator_gather_votes(contest_count_list, question_count_list)
  contest_count_list.each do |cc|
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
  question_count_list.each do |qc|
    qid = qc['question_ident']
    tab_incr_question_xvote(qid,'overvote_count',qc['overvote_count'])
    tab_incr_question_xvote(qid,'undervote_count',qc['undervote_count'])
    qc['answer_count_list'].each do |anscount|
      tab_incr_question_answer_count(qid,anscount['answer'],anscount['count'])
    end
  end
end

def tabulator_new(edinfo)
  {"tabulator_count"=>
    {"election_ident"=>edinfo['election']['ident'],
      "jurisdiction_ident"=>edinfo['jurisdiction']['ident'],
      "audit_trail"=>
      {"software"=>"TTV Tabulator v JVC",
        "file_ident"=>tabulator_count_file(),
        "operator"=>"El Jefe",
        "create_date"=>Time.new.strftime("%Y-%m-%d %H:%M:%S"),
      },
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

def tabulator_dump_data
  print "Dumping Data Structures\n"
  $unique_ids.sort.each do |k, v|
    print "  ",k.capitalize," IDs: ",v.inspect.gsub(/\"/,''),"\n"
  end
  print "  Precinct Districts and Expected Counts:\n"
  $precinct_distids.sort.each do |k, v|
    print "    #{k}: ",v.inspect.gsub(/\"/,''),"\n"
    $precinct_counts[k].each do |c, n|
      print "      #{c}: ",n,"\n"
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
