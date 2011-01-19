require "yaml"
require "tab_check_syntax"

$ts_test_new = {"test_new"=>{"|OR|"=>[{"bar"=>"String"},{"bart"=>"String"}]}}
$ts_test_opt = {"test_opt"=>"String", "|OPT|"=>{"foo"=>"Integer"}}
$ts_test_or = {"test_or"=>"String", "|OR|"=>[{"foo"=>"Date"},{"bar"=>"Date"}]}
$ts_unknown_type = {"unknown_type"=>100}
$ts_unknown_string = {"unknown_string"=>"Foobar"}
$ts_district_info = {"ident"=>"Atomic"}
$ts_precinct_info = {"ident"=>"Atomic"}
$ts_precount_info =
  {"ident"=>"Atomic",
    "district_ident_list"=>["Atomic"],
    "expected_count_list"=>[{"counter_ident"=>"Atomic", "count"=>"Integer"}]}
$ts_contest_info =
  {"ident"=>"Atomic",
  "district_ident"=>"Atomic"}
$ts_candidate_info =
  {"ident"=>"Atomic",
  "contest_ident"=>"Atomic"}
$ts_question_info =
  {"ident"=>"Atomic",
  "district_ident"=>"Atomic",
  "question"=>"String",
  "answer_list"=>["String"]}
$ts_counter_info = {"ident"=>"Atomic"}
$ts_election_definition_info =
  {"election"=>{"ident"=>"Atomic"},
  "jurisdiction"=>{"ident"=>"Atomic"},
  "district_list"=>[$ts_district_info],
  "precinct_list"=>[$ts_precinct_info],
  "precount_list"=>[$ts_precount_info],
  "contest_list"=>[$ts_contest_info],
  "candidate_list"=>[$ts_candidate_info],
  "question_list"=>[$ts_question_info],
  "counter_list"=>[$ts_counter_info]}
$ts_election_definition =
  {"election_definition"=>$ts_election_definition_info}
$ts_candidate_count = {"candidate_ident"=>"Atomic","count"=>"Integer"}
$ts_contest_count =
  {"contest_ident"=>"Atomic",
  "undervote_count"=>"Integer",
  "overvote_count"=>"Integer",
  "|OPT|"=>{"writein_count","Integer"},
  "candidate_count_list"=>[$ts_candidate_count]}
$ts_answer_count = {"answer"=>"String", "count"=>"Integer"}
$ts_question_count =
  {"question_ident"=>"Atomic",
  "undervote_count"=>"Integer",
  "overvote_count"=>"Integer",
  "answer_count_list"=>[$ts_answer_count]}
$ts_audit_trail_info =
  {"file_ident"=>"Atomic",
  "create_date"=>"Date",
  "operator"=>"String",
  "software"=>"String",
  "|OPT1|"=>{"hardware"=>"String"},
  "|OPT2|"=>{"provenance"=>["String"]}}
$ts_audit_trail = {"audit_trail"=>$ts_audit_trail_info}
$ts_counter_count =
  {"counter_count"=>
  {"audit_trail"=>$ts_audit_trail_info,
    "election_ident"=>"Atomic",
    "jurisdiction_ident"=>"Atomic",
    "precinct_ident"=>"Atomic",
    "reporting_group"=>"String",
    "counter_ident"=>"Atomic",
    "cast_ballot_count"=>"Integer",
    "contest_count_list"=>[$ts_contest_count],
    "question_count_list"=>[$ts_question_count]}}
$ts_tabulator_count =
  {"tabulator_count"=>
  {"audit_trail"=>$ts_audit_trail_info,
    "election_ident"=>"Atomic",
    "jurisdiction_ident"=>"Atomic",
    "election_definition"=>$ts_election_definition_info,
    "counter_count_list"=>[$ts_counter_count],
    "contest_count_list"=>[$ts_contest_count],
    "question_count_list"=>[$ts_question_count]}}

def read_yaml_file(file, label = "")
  print "Reading YAML #{label} file: #{file}\n" if label != ""
  File.open(file) { |infile| YAML::load(infile) }
end
     
def write_yaml_file(file, datum, label = "")
  print "Writing YAML #{label} file: #{file}\n" if label != ""
  File.open(file, "w") { |outfile| YAML::dump(datum, outfile) }
end
     
def write_schema_files
  write_yaml_file("Schemas/test_new_schema.yml",$ts_test_new)
  write_yaml_file("Schemas/test_opt_schema.yml",$ts_test_opt)
  write_yaml_file("Schemas/test_or_schema.yml",$ts_test_or)
  write_yaml_file("Schemas/unknown_type_schema.yml",$ts_unknown_type)
  write_yaml_file("Schemas/unknown_string_schema.yml",$ts_unknown_string)
  write_yaml_file("Schemas/district_info_schema.yml",$ts_district_info)
  write_yaml_file("Schemas/precinct_info_schema.yml",$ts_precinct_info)
  write_yaml_file("Schemas/precount_info_schema.yml",$ts_precount_info)
  write_yaml_file("Schemas/contest_info_schema.yml",$ts_contest_info)
  write_yaml_file("Schemas/candidate_info_schema.yml",$ts_candidate_info)
  write_yaml_file("Schemas/question_info_schema.yml",$ts_question_info)
  write_yaml_file("Schemas/counter_info_schema.yml",$ts_counter_info)
  write_yaml_file("Schemas/election_definition_schema.yml",$ts_election_definition)
  write_yaml_file("Schemas/answer_count_schema.yml",$ts_answer_count)
  write_yaml_file("Schemas/question_count_schema.yml",$ts_question_count)
  write_yaml_file("Schemas/candidate_count_schema.yml",$ts_candidate_count)
  write_yaml_file("Schemas/contest_count_schema.yml",$ts_contest_count)
  write_yaml_file("Schemas/counter_count_schema.yml",$ts_counter_count)
  write_yaml_file("Schemas/audit_trail_schema.yml",$ts_audit_trail)
  write_yaml_file("Schemas/tabulator_count_schema.yml",$ts_tabulator_count)
end
     
def schema_check(type, extra = "")
  data_file = "Tests/Syntax/#{type}" + extra + ".yml"
  data = read_yaml_file(data_file, "data")
  schema_file = "Schemas/#{type}_schema.yml"
  schema = read_yaml_file(schema_file, "schema")
  if (! check_syntax(schema, data))
    print "\nERROR - THE PREVIOUS TEST MUST NOT FAIL\n\n"
    exit(1)
  else
    print "Check Syntax: #{type}: OK\n\n"
  end
end
     
def schemas_check_syntax
  schema_check("test_opt")
  schema_check("test_or")
  schema_check("district_info")
  schema_check("precinct_info")
  schema_check("precount_info")
  schema_check("counter_info")
  schema_check("candidate_info")
  schema_check("contest_info")
  schema_check("question_info")
  schema_check("election_definition")
  schema_check("answer_count", "_A")
  schema_check("answer_count", "_B")
  schema_check("question_count")
  schema_check("candidate_count", "_1")
  schema_check("candidate_count", "_2")
  schema_check("contest_count")
  schema_check("audit_trail")
  schema_check("audit_trail", "_hardware")
  schema_check("audit_trail", "_provenance")
  schema_check("audit_trail", "_nil_provenance")
  schema_check("audit_trail", "_all")
  schema_check("counter_count")
  schema_check("tabulator_count")
end
     
def schema_check_error(type, extra1, extra2 = "", extra3 = "")
  data_file = "Tests/Syntax/Errors/#{type}_" + extra1.inspect + ".yml"
  data = read_yaml_file(data_file, "data")
  schema_file = "Schemas/#{type}_schema.yml"
  schema = read_yaml_file(schema_file, "schema")
  if (check_syntax(schema, data))
    print "\nERROR - THE TEST MUST FAIL - CHECKING ERROR CODES\n"
    exit(1)
  end
  if ((extra3 != "") && (extra3 != check_syntax_error_codes[2]))
    print "\nERROR - 3rd ERROR CODE FOR TEST MUST BE: #{extra3}\n\n"
    exit(1)
  end
  if ((extra2 != "") && (extra2 != check_syntax_error_codes[1]))
    print "\nERROR - 2nd ERROR CODE FOR TEST MUST BE: #{extra2}\n\n"
    exit(1)
  end
  if (extra1 != check_syntax_error_codes[0])
    print "\nERROR - 1st ERROR CODE FOR TEST MUST BE: #{extra1}\n\n"
    exit(1)
  end
  print "Check Syntax: #{type}: OK\n\n"
end

def schemas_check_syntax_errors
  schema_check_error("unknown_type",0)
  schema_check_error("unknown_string",1)
  schema_check_error("question_info",2)
  schema_check_error("test_opt",3)
  schema_check_error("test_or",4)
  schema_check_error("district_info",5)
  schema_check_error("precount_info",6)
  schema_check_error("audit_trail",7)
  schema_check_error("question_info",2,8)
  schema_check_error("contest_info",9)
  schema_check_error("test_opt",3,10)
  schema_check_error("test_opt",3,10,11)
  schema_check_error("test_or",12)
  schema_check_error("test_or",4,10,13)
  schema_check_error("test_or",14)
end
  
begin
  # There is a problem with Syck, loading true for Yes, etc. Must be fixed.
  # Another problem concerns loading strings, all should be double-quoted
  YAML::Syck::ImplicitTyping = 1 
  $check_syntax_trace = true if ARGV.include?("trace")
  write_schema_files()
  schemas_check_syntax_errors() # if ARGV.include?("all")
  print "TABULATOR SCHEMAS SYNTAX ERROR TESTS: OK\n\n"
  schemas_check_syntax() # if ARGV.include?("all")
  print "TABULATOR SCHEMAS SYNTAX TESTS: OK\n\n"
  $check_syntax_trace = true
  #schema_check("test_new")
end
