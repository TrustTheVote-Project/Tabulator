require "yaml"
require "tab_check_syntax"

class UidErr < Exception
  def initialize(tag, mesg)
    print "\n**#{tag} ERROR** #{mesg}\n\n"
  end
end

class ShouldntErr < Exception
  def initialize(tag, mesg)
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
  $count_info = Hash.new { |h,k| h[k] = {} }
  $precinct_counts = Hash.new { |h,k| h[k] = {} }
end

def tab_init_votes
  $count_info.sort.each do |k, v|
    v['overvote_count']=0
    v['undervote_count']=0
    v['writein_count']=0 if ($count_info[k]['type'] == 'contest')
    v['items'].each { |id| v[id]=0 }
  end
end

def tab_incr_vote(conid, id, n)
  tab_check_vote(conid,id)
  $count_info[conid][id] += n
end

def tab_check_vote(conid, id) # Keep making sure $count_info is well-formed
  raise ShouldntErr.new('UV',"No such Contest: #{conid}") unless
    $count_info.key?(conid)
  raise ShouldntErr.new('UV',"No such #{conid} Vote Item: #{id}") unless
    $count_info[conid].key?(id)
  vote = $count_info[conid][id]
  raise ShouldntErr.new('UV',"Non-numeric #{conid}/#{id} Vote: #{vote}") unless
    vote.is_a?(Integer)
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
    $count_info[conid]['items'] = []
    $count_info[conid]['type'] = 'contest'
  end
  edinfo['candidate_list'].each do |candidate|
    canid = candidate['ident']
    conid = candidate['contest_ident']
    tab_check_candidate_contest_id(canid,conid)
    tab_new_count_subid(conid,canid,'Candidate','candidate')
  end
  edinfo['question_list'].each do |question|
    qid = question['ident']
    did = question['district_ident']
    tab_check_district_id(did, qid, 'Question')
    $count_info[qid]['items'] = []
    $count_info[qid]['type'] = 'question'
    question['answer_list'].each do |answer|
      tab_new_count_subid(question['ident'],answer,'Answer')
    end
  end
  tab_init_votes()
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

def tab_new_count_subid(uid, subid, text, subname = '')
  tab_check_subid($count_info[uid]['items'],'Contest',uid,subid,text,subname)
  $count_info[uid]['items'].push(subid.to_s)
end

def tab_uid_exists?(name, uid)
  #print "tab_uid_exists? name: #{name} uid: #{uid}\n\n"
  return $unique_ids[name].include?(uid.to_s)
end

def tab_check_uid(tag, name, uid) # Invalid if Non-existent
  raise UidErr.new(tag,"Invalid #{name.capitalize}: #{uid}") unless
    tab_uid_exists?(name,uid)
end

def tab_check_count_items(ids, uid, text) # Not all present
  if (ids.length != $count_info[uid]['items'].length)
      unids = $count_info[uid]['items'] - ids
      unids = unids.inspect.sub(/\[\"/,'(').sub(/\"\]/,')').gsub(/\"/,'')
    raise UidErr.new('CC',"Not all #{text} #{unids} appear in Contest: #{uid}") 
  end
end

def tab_check_count_item(conid, id, existing, text) # Invalid, Improper, Duplicate
  if (text == 'Candidate')
    raise UidErr.new('CC',"Invalid Contest (#{conid}) Candidate: #{id}") unless
      tab_uid_exists?('candidate',id)
  end
  raise UidErr.new('CC',"Improper Contest (#{conid}) #{text}: #{id}") unless
    $count_info[conid]['items'].include?(id.to_s)
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

def tab_validate_actual_count(ac, acids)
  type = ac['type']
  acid = ac['ident']
  if (type == "contest")
    acids.push(acid.to_s) if tab_check_contest_id(acid, acids)
    canids = []
    ac['candidate_count_list'].each do |offcount|
      canid = offcount['candidate_ident']
      tab_check_count_item(acid, canid, canids, 'Candidate')
      canids.push(canid.to_s)
    end
    tab_check_count_items(canids,acid,'Candidates')
  else
    acids.push(acid.to_s) if tab_check_question_id(acid, acids)
    ansids = []
    ac['answer_count_list'].each do |anscount|
      ansid = anscount['answer']
      tab_check_count_item(acid,ansid,ansids,'Answer')
      ansids.push(ansid.to_s)
    end
    tab_check_count_items(ansids,acid,'Answer')
  end
  acids
end

def tab_build_running_counts
  $count_info.keys.sort.collect do |k|
    ((v = $count_info[k])['type'] == 'contest' ?
     {"type"=>"contest",
       "ident"=> k,
       "undervote_count"=> v['undervote_count'],
       "overvote_count"=> v['overvote_count'],
       "writein_count"=> v['writein_count'],
       "candidate_count_list"=>
       v['items'].collect { |id| {"candidate_ident"=>id, "count"=> v[id]}}} :
     {"type"=>"question",
       "ident"=> k,
       "undervote_count"=> v['undervote_count'],
       "overvote_count"=> v['overvote_count'],
       "answer_count_list"=>
       v['items'].collect { |ans| {"answer"=>ans, "count"=> v[ans]}}})
  end
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
  ccval['actual_count_list'].each do |actual_count|
    conids = tab_validate_actual_count(actual_count, conids)
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
    counter_count['actual_count_list'].each do |actual_count|
      conid = actual_count['ident']
      accumulated_conids.push(conid.to_s) unless accumulated_conids.include?(conid.to_s)
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
  tabulator_gather_votes(tc['tabulator_count']['running_count_list'])
  tc
end

def tabulator_gather_votes(actual_count_list)
  actual_count_list.each do |acount|
    acid = acount['ident']
    tab_incr_vote(acid,'overvote_count',acount['overvote_count'])
    tab_incr_vote(acid,'undervote_count',acount['undervote_count'])
    if (acount['type'] == "contest")
      tab_incr_vote(acid,'writein_count',acount['writein_count'])
      acount['candidate_count_list'].each do |cancount|
        tab_incr_vote(acid,cancount['candidate_ident'],cancount['count'])
      end
    else
      acount['answer_count_list'].each do |anscount|
        tab_incr_vote(acid,anscount['answer'],anscount['count'])
      end
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
      "running_count_list"=>tab_build_running_counts(),
      "counter_count_list"=>[]}}
end

def tabulator_update(tc, cc)
  fid = cc['counter_count']['audit_trail']['file_ident']
  at = tc['tabulator_count']['audit_trail']
  (at['provenance'] ? at['provenance'].push(fid.to_s) : at['provenance'] = [fid])
  tc['tabulator_count']['running_count_list'] = tab_build_running_counts()
  tc['tabulator_count']['counter_count_list'].push(cc)
  tc
end

def tabulator_spreadsheet
  info = $count_info.collect do |k, v|
    [['CONTEST', 'undervote_count','overvote_count','writein_count'] +
     v['items'].collect { |id| id },
     [k, v['undervote_count'],v['overvote_count'],
     ($count_info[k]['type'] == 'contest' ? v['writein_count'] : 0 )] +
     v['items'].collect { |id| v[id] }]
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
  print "  Contest/Question Info:\n"
  $count_info.sort.each do |k, v|
    print "    #{k}: ",v['type']," ",v['items'].inspect.gsub(/\"/,''),"\n"
    print "      overvote = #{v['overvote_count']}, "
    print "undervote = #{v['undervote_count']}"
    (v['type'] == 'contest' ?
     (print ", writeins = #{v['writein_count']}\n") :
     (print "\n"))
    v['items'].sort.each do |item|
      print "      #{item} = #{v[item]}\n"
    end
  end
  print "\n"
end
