require "yaml"
require "check_syntax_yaml"
require "tabulator"

def operator_help
  print "\nCommands:\n\n"
  print "  ruby operator.rb          \# same as help\n"
  print "  ruby operator.rb help     \# print help info\n"
  print "  ruby operator.rb reset    \# reset tabulator\n"
  print "  ruby operator.rb output   \# print CSV voting results\n"
  print "  ruby operator.rb data     \# print tabulator data structures\n"
  print "  ruby operator.rb state    \# print tabulator state\n\n"
  print "  ruby operator.rb [trace] [print] <FILE>\n\n"
  print "       \# trace: optional arg turns on debug tracing\n"
  print "       \# print: optional arg prints data structures afterwards\n"
  print "       \#\n"
  print "       \# <FILE>: a YAML file containing ...\n"
  print "       \#   jurisdiction definition: syntax checks, validates, installs\n"
  print "       \#   counter count: syntax checks, validates, updates tabulator\n"
  print "       \#   tabulator count: syntax checks, validates (not installed)\n\n"
end

def operator_reset
  print "\nTabulator RESET..."
  tabulator_initaliaze()
  tcfile = tabulator_count_file()
  if (File.exists?(tcfile))
    print " Deleting Tabulator Count file: #{tcfile}\n"
    File.delete(tcfile)
  end
  csvfile = tabulator_csv_file()
  if (File.exists?(csvfile))
    print "  Deleting Tabulator CSV file: #{csvfile}\n"
    File.delete(csvfile)
  end
  print "\n"
end

def operator_output(cs)
  op_state_exit_initial()
  tc = op_instantiate_tabulator(cs)
  lines = tabulator_spreadsheet()
  print "\nCSV Output:\n\n"
  print lines,"\n"
  outfile = File.open(tabulator_csv_file(), 'w')
  outfile.puts lines
  outfile.close()
end

def operator_data(cs)
  op_state_exit_initial()
  tc = op_instantiate_tabulator(cs)
  print YAML::dump(tc),"\n"
  tabulator_dump_data()
end

def operator_state(cs)
  state = op_state_exit_initial()
  print "\nChecking Tabulator State\n\n"
  tc = op_instantiate_tabulator(cs)
  if (tc['tabulator_count']['counter_count_list'].length == 0)
    print "\nNo counts accumulated so far\n"
    print "\nTabulator State: ",state,"\n\n"
    return
  end
  missing = op_state_donep(tc, true)
  print "\nTotal Missing Counts: #{missing.length}\n"
  label = ''
  if (missing.length == 0)
    print "\nTabulator State: DONE!\n"
  else
    print "\nTabulator State: #{state}\n"
  end
end

def op_state_exit_initial
  state = tabulator_state()
  if (state =~ /^INIT/)
    print "\nTabulator State: ",state,"\n\n"
    exit(0)
  end
  state
end

def op_state_donep(tc, printit = false)
  missing = tabulator_missing_counts(tc)
  if (printit)
    op_print_missing_counts(missing)
    missing
  else
    missing.length == 0
  end
end

def op_print_missing_contests(label, unconids)
  if (unconids.length == 0)
    print "\n\n"
  else
    print label,"No reporting data on the following contests: "
    print unconids.inspect.gsub(/\"/,''),"\n\n"
  end
end

def op_print_missing_counts(missing)
  if (missing.length == 0)
    print "\nAll Counts Accumulated\n"
  else
    print "\nMissing Counts:\n"
    missing.each do |cid, rg, pid|
      print "  #{cid} #{rg} #{pid}\n"
    end
  end
end

def op_instantiate_tabulator(cs, printit = true)
  print "Instantiating Tabulator (Check Syntax, Validate)\n" if printit
  tcfile = tabulator_count_file()
  tc = op_read_yaml_file(tcfile)
  if (tc.is_a?(Hash) && (tc.keys.length == 1) &&
      (tc.keys[0] == 'tabulator_count'))
    schema_file = "Schemas/tabulator_count_schema.yml"
    schema = op_read_yaml_file(schema_file)
    if (cs.check_syntax(schema, tc).length == 0)
      tabulator_initaliaze()
      tabulator_validate_tabulator_count(tc)
    else
      print "FATAL ERROR, syntax check failure on Tabulator Count file #{tcfile}\n"
      exit(1)
    end
  else
    print "FATAL ERROR, invalid Tabulator Count file #{tcfile}, must RESET\n"
    exit(1)
  end
end

def op_read_yaml_file(file, label = '')
  print "Reading YAML #{label} file: #{file}\n" if label != ''
  File.open(file) { |infile| YAML::load(infile) }
end

def op_write_yaml_file(file, datum, label = '')
  print "Writing YAML #{label} file: #{file}\n" if label != ''
  File.open(file, 'w') { |outfile| YAML::dump(datum, outfile) }
end

def op_check_syntax(cs, file)
  if ((datum = op_read_yaml_file(file, 'data')) &&
      (datum.is_a?(Hash) && (datum.keys.length == 1)) &&
      (type = datum.keys[0]) && 
      (schema_file = "Schemas/#{type}_schema.yml") &&
      File.exists?(schema_file) &&
      (schema = op_read_yaml_file(schema_file, 'schema')) &&
      cs.check_syntax(schema, datum).length == 0)
    datum
  end
end

def operator_file(cs, file1, file2)
  datum = op_check_syntax(cs, file1)
  if (! datum.is_a?(Hash))
    print "Unexpected contents of tabulator file: #{file1}\n"
    exit(1)
  end
  op_state_exit_initial() if (datum.keys[0] == 'counter_count')
  print "Check Syntax: #{datum.keys[0]}: OK\n"
  print "Validating: #{datum.keys[0]}"
  type = datum.keys[0]
  case type
  when 'election_definition'
    print "\nElection Definition must be preceeded by Jurisdiction Definition\n"
    exit(1)
  when 'jurisdiction_definition'
    jd = datum
    tabulator_initaliaze()
    tabulator_validate_jurisdiction_definition(jd['jurisdiction_definition'])
    print ": OK\n\n"
    if (file2 == '' || ! File.exists?(file2))
      print "Jurisdiction file must be followed by Election Definition file: #{file2}\n"
      exit(1)
    end
    datum = op_check_syntax(cs, file2)
    if (! datum.is_a?(Hash) || datum.keys[0] != "election_definition")
      print "Unexpected contents of Election Definition file: #{file2}\n"
      exit(1)
    end
    print "Check Syntax: #{datum.keys[0]}: OK\n"
    print "Validating: #{datum.keys[0]}"
    ed = datum
    tabulator_validate_election_definition(ed['election_definition'])
    tc = tabulator_new(jd['jurisdiction_definition'], ed['election_definition'])
    print ": OK\n\n"
    op_write_yaml_file(tabulator_count_file(),tc,'Tabulator Count')
  when 'counter_count'
    cc = datum
    tc = op_instantiate_tabulator(cs, false)
    tabulator_check_duplicate_counter_count(cc['counter_count'])
    tabulator_validate_counter_count(cc['counter_count'])
    print ": OK\n\n"
    tabulator_gather_counter_count_votes(cc['counter_count'])
    tc = tabulator_update(tc,cc)
    op_write_yaml_file(tabulator_count_file(),tc,'Tabulator Count')
    print "TABULATOR DONE!!!\n\n" if op_state_donep(tc)
  when 'tabulator_count'
    tabulator_initaliaze()
    tabulator_validate_tabulator_count(datum)
    print ": OK\n\n"
  else
    print "Unknown tabulator file type: #{type}\n"
    exit(1)
  end
  op_print_warnings(true)
end

def op_print_warnings(short = false)
  warnings = tabulator_warnings()
  if (warnings.length > 0)
    print "There were #{warnings.length} WARNINGS!\n"
    warnings.each { |text| print "  ",text,"\n" } unless short
  end
end  

begin
  cs = CheckSyntaxYaml.new
  operator_print = false
  file1 = ''
  file2 = ''
  ARGV.each do |arg|
    (arg == 'trace' ? (cs.trace(true)) :
     (arg == 'print' ? (operator_print = true) :
      (file1 == '' ? (file1 = arg) : (file2 = arg))))
  end
  print "Trace ON\n" if ARGV.include?('trace')
  print "Print ON\n" if operator_print
  if (file1 == '' || file1 == 'help')
    operator_data(cs) if operator_print
    operator_help() unless operator_print and file1 == ''
    exit(0)
  elsif (file1 == 'reset')
    operator_reset()
    exit(0)
  elsif (file1 == 'output')
    operator_data(cs) if operator_print
    operator_output(cs)
    exit(0)
  elsif (file1 == 'data')
    operator_data(cs)
    exit(0)
  elsif (file1 == 'state')
    operator_data(cs) if operator_print
    operator_state(cs)
    exit(0)
  elsif (File.exists?(file1))
    operator_file(cs, file1, file2)
    operator_data(cs) if operator_print;
  else
    print "\nERROR, non-existent file: #{file1}\n\n"
  end
rescue UidErr, ShouldntErr
  op_print_warnings() if (ARGV.include?('trace') || operator_print)
  exit(1)
else
  op_print_warnings() if (ARGV.include?('trace') || operator_print)
  exit(0)
end
