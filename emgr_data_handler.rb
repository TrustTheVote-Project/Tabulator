require "yaml"

$DEBUG = true
 
def die(message)
  print message + "\n"
  exit(1)
end

def die_file(file, type)
  die("Invalid " + type + " File: " + file)
end

def die_file_contents(file, type, contents)
  die("Invalid Key (" + contents + ") in " + type + " File: " + file)
end

def process_candidates(cands) # Because the DC dataset has some without idents
  cnum = 5000
  cands['candidates'].each do |c| 
    contest_ident = c['contest_ident']
    unless (c.key?('ident'))
      cnum += 1
      c['ident'] = "cand-" + cnum.to_s
    end
  end
  if (cnum > 5000)
    n = cnum - 5000
    print "**WARNING** Candidates without idents (fake ones supplied): " +
      n.to_s + "\n"
  end
  return cands
end

def is_emgr_file?(file,type,keys)
  return false if (file == "")
  print "Processing EMGR File: " + file + "\n"
  x = File.open(file) { |infile| YAML::load(infile) }
  if (x.is_a?(Hash) && (x.keys[0] == 'body') && x['body'].is_a?(Hash))
    keys.each do |k|
      die_file_contents(file, type, k) unless x['body'].key?(k)
    end
    print YAML::dump(x['body']),"\n" if $DEBUG
    return x['body']
  else
    die_file(file, type)
  end
end

$CANDFILE = "Tests/dc november 2010/dc-real-candidates.yml"
$ELECFILE = "Tests/dc november 2010/dc-real-elect.yml"
$JURIFILE = "Tests/dc november 2010/dc-real-juris.yml"
$QUESFILE = ""

def datasetsVA
  $CANDFILE = "Tests/va november 2010/cand-vipFeedWithBallotQuestions.yml"
  $ELECFILE = "Tests/va november 2010/elect-vipFeedWithBallotQuestions.yml"
  $JURIFILE = "Tests/va november 2010/juris-vipFeedWithBallotQuestions.yml"
  $QUESFILE = "Tests/va november 2010/va-question-handcrafted-with-answers.yml"
end

begin
  $DEBUG = false
  datasetsVA() if ARGV.length > 0
  cands = is_emgr_file?($CANDFILE,'Candidates',['candidates'])
  cands = process_candidates(cands)
  elecs = is_emgr_file?($ELECFILE,'Election',['elections','contests'])
  juris = is_emgr_file?($JURIFILE,'Jurisdiction',['districts','precincts',
                                                  'district_sets','splits'])
  quest = is_emgr_file?($QUESFILE,'Questions',['questions'])
  election_definition =
      {"election_definition"=>
        {"audit_trail"=>{"software"=>"TTV Tabulator v JVC",
            "file_ident"=>"FILE_FOO_1",
            "operator"=>"JVC",
            "create_date"=>Time.new.strftime("%Y-%m-%d %H:%M:%S") },
          "jurisdiction"=>{"ident"=>"JURISDICTION_1",
            "display_name"=>"1st Jurisdiction"},
          "election"=>elecs['elections'][0],
          "district_list"=>juris['districts'],
          "precinct_list"=>juris['precincts'],
          "precount_list"=>[],
          "contest_list"=>elecs['contests'],
          "candidate_list"=>cands['candidates'],
          "question_list"=>(quest.is_a?(Hash) ? quest['questions'] : []),
          "counter_list"=>[]
        }}
  file = "EMGR_ELECTION_DEFINITION.yml"
  label = "Election Definition"
  print "Writing YAML #{label} file: #{file}\n"
  File.open(file, 'w') { |outfile| YAML::dump(election_definition, outfile) }
end
