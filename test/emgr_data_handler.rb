#!/usr/bin/ruby

require "yaml"

# This is a temporary class used to process some test datasets from the DC and
# Viginia elections held in November 2010. 

class TempEmgrDH # Temporary EMGR Data Handler for Tabulator

  def initialize
    @debug = false
  end

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
      print YAML::dump(x['body']),"\n" if @debug
      return x['body']
    else
      die_file(file, type)
    end
  end

  begin
    @debug = false
    if (ARGV.length > 0)
      candfile = "Tests/VA/cand-vipFeedWithBallotQuestions.yml"
      elecfile = "Tests/VA/elect-vipFeedWithBallotQuestions.yml"
      jurifile = "Tests/VA/juris-vipFeedWithBallotQuestions.yml"
      quesfile = "Tests/VA/va-question-handcrafted-with-answers.yml"
    else
      candfile = "Tests/DC/dc-real-candidates.yml"
      elecfile = "Tests/DC/dc-real-elect.yml"
      jurifile = "Tests/DC/dc-real-juris.yml"
      quesfile = ""
    end
    tedh = TempEmgrDH.new
    cands = tedh.is_emgr_file?(candfile,'Candidates',['candidates'])
    cands = tedh.process_candidates(cands)
    elecs = tedh.is_emgr_file?(elecfile,'Election',['elections','contests'])
    juris = tedh.is_emgr_file?(jurifile,'Jurisdiction',['districts','precincts',
                                                   'district_sets','splits'])
    quest = tedh.is_emgr_file?(quesfile,'Questions',['questions'])
    jurisdiction_definition =
      {"jurisdiction_definition"=>
      {"ident"=>"JURISDICTION_1",
        "district_list"=>juris['districts'],
        "precinct_list"=>juris['precincts'],
        "audit_header"=>{"software"=>"TTV Tabulator v El Jefe",
          "file_ident"=>"ED_1",
          "operator"=>"El Jefe",
          "create_date"=>Time.new.strftime("%Y-%m-%d %H:%M:%S") }}}
    file = "EMGR_JD.yml"
    label = "Jurisdiction Definition"
    print "Writing YAML #{label}: #{file}\n"
    File.open(file, 'w') { |outfile| YAML::dump(jurisdiction_definition, outfile) }
    election_definition =
      {"election_definition"=>
      {"audit_header"=>{"software"=>"TTV Tabulator v El Jefe",
          "file_ident"=>"ED_1",
          "operator"=>"El Jefe",
          "create_date"=>Time.new.strftime("%Y-%m-%d %H:%M:%S") },
        "election"=>{"start_date"=>elecs['elections'][0]["start_date"],
          "type"=>elecs['elections'][0]["type"],
          "ident"=>elecs['elections'][0]["ident"]},
        "jurisdiction_ident"=>"JURISDICTION_1",
        "reporting_group_list"=>[],
        "expected_count_list"=>[],
        "contest_list"=>elecs['contests'],
        "candidate_list"=>cands['candidates'],
        "question_list"=>(quest.is_a?(Hash) ? quest['questions'] : []),
        "counter_list"=>[]
      }}
    file = "EMGR_ED.yml"
    label = "Election Definition"
    print "Writing YAML #{label}: #{file}\n"
    File.open(file, 'w') { |outfile| YAML::dump(election_definition, outfile) }
  end

end
