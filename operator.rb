require "yaml"
require "check_syntax_yaml"
require "tabulator"

TABULATOR_COUNT_FILE = "TABULATOR_COUNT.yml"
TABULATOR_CSV_FILE = "TABULATOR_COUNT.csv"

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
  tab = Tabulator.new
  once = false
  tcfile = TABULATOR_COUNT_FILE
  if (File.exists?(tcfile))
    print " Deleting Tabulator Count file: #{tcfile}\n"
    File.delete(tcfile)
    once = true
  end
  csvfile = TABULATOR_CSV_FILE
  if (File.exists?(csvfile))
    print "  Deleting Tabulator CSV file: #{csvfile}\n"
    File.delete(csvfile)
    once = true
  end
  (once ? print("\n") : print(" Nothing To Do\n\n"))
end

def operator_output(tab = false)
  op_exit_initial()
  tab = Tabulator.new if tab == false
  tc = op_instantiate_tabulator(tab)
  lines = tab.create_tabulator_spreadsheet()
  print "\nCSV Output:\n\n"
  print lines,"\n"
  outfile = File.open(tabulator_csv_file(), 'w')
  outfile.puts lines
  outfile.close()
end

def operator_data(tab = false)
  op_exit_initial()
  tab = Tabulator.new if tab == false
  tc = op_instantiate_tabulator(tab)
  tab.dump_tabulator_data(tc)
  tab
end

def operator_state(printit = false)
  op_exit_initial()
  tab = Tabulator.new
  print "\nChecking Tabulator State\n\n"
  tc = op_instantiate_tabulator(tab)
  op_print_state(tab, tc, printit)
end

def op_print_state(tab, tc, printit)
  mystate = tab.current_state(tc)
  if (!mystate.is_a?(Array))
    print "Tabulator State Not An Array: #{mystate.inspect}\n"
    exit(1)
  end
  state = mystate[0]
  print "\nTabulator State: #{state}\n\n"
  if (printit && state =~ /^ACCUM/)
    print "Missing Counts:\n"
    missing = mystate[1]
    missing.each { |cid, rg, pid|
      print "  Counter: #{cid}, Precinct: #{pid}, Reporting Group: #{rg}\n"}
  end
end  

def op_exit_initial()
  if (!File.exists?(TABULATOR_COUNT_FILE))
    print "\nTabulator State: INITIAL (Waiting for Jurisdiction Definition)\n"
    exit(0)
  end
end

def op_instantiate_tabulator(tab, printit = true)
  errs = [[], []]
  print "Instantiating Tabulator (Check Syntax, Validate)\n" if printit
  tcfile = TABULATOR_COUNT_FILE
  tc = op_read_yaml_file(tcfile)
  if (tc.is_a?(Hash) && (tc.keys.length == 1) &&
      (tc.keys[0] == 'tabulator_count'))
    schema_file = "Schemas/tabulator_count_schema.yml"
    schema = op_read_yaml_file(schema_file)
    if (CheckSyntaxYaml.new.check_syntax(schema, tc, true).length == 0)
      errs = tab.validate_tabulator_count(tc['tabulator_count'])
    else
      print "FATAL ERROR, syntax check failure on Tabulator Count file #{tcfile}\n"
      exit(1)
    end
  else
    print "FATAL ERROR, invalid Tabulator Count file #{tcfile}, must RESET\n"
    exit(1)
  end
  tc
end

def op_read_yaml_file(file, label = '')
  print "Reading YAML #{label} file: #{file}\n" if label != ''
  File.open(file) { |infile| YAML::load(infile) }
end

def op_write_yaml_file(file, datum, label = '')
  print "Writing YAML #{label} file: #{file}\n" if label != ''
  File.open(file, 'w') { |outfile| YAML::dump(datum, outfile) }
end

def op_check_syntax(file)
  if ((datum = op_read_yaml_file(file, 'data')) &&
      (datum.is_a?(Hash) && (datum.keys.length == 1)) &&
      (type = datum.keys[0]) && 
      (schema_file = "Schemas/#{type}_schema.yml") &&
      File.exists?(schema_file) &&
      (schema = op_read_yaml_file(schema_file, 'schema')) &&
      CheckSyntaxYaml.new.check_syntax(schema, datum).length == 0)
    datum
  end
end

def operator_file(file1, file2)
  tab = Tabulator.new
  errs = [[], []]
  datum = op_check_syntax(file1)
  if (! datum.is_a?(Hash))
    print "Unexpected contents of tabulator file: #{file1}\n"
    exit(1)
  end
  op_exit_initial() if (datum.keys[0] == 'counter_count')
  print "Check Syntax: #{datum.keys[0]}: OK\n"
  print "Validating: #{datum.keys[0]}\n"
  type = datum.keys[0]
  case type
  when 'election_definition'
    print "Election Definition must be preceeded by Jurisdiction Definition\n"
    exit(1)
  when 'jurisdiction_definition'
    jd = datum
    errs = tab.validate_jurisdiction_definition(jd['jurisdiction_definition'])
    print "Jurisdiction Definition OK\n\n"
    if (file2 == '' || ! File.exists?(file2))
      print "Jurisdiction file must be followed by Election Definition file: #{file2}\n"
      exit(1)
    end
    datum = op_check_syntax(file2)
    if (! datum.is_a?(Hash) || datum.keys[0] != "election_definition")
      print "Unexpected contents of Election Definition file: #{file2}\n"
      exit(1)
    end
    print "Check Syntax: #{datum.keys[0]}: OK\n"
    print "Validating: #{datum.keys[0]}\n"
    ed = datum
    errs = tab.validate_election_definition(ed['election_definition'])
    print "Election Definition OK\n\n"
    tc = tab.create_tabulator_count(jd, ed, TABULATOR_COUNT_FILE)
    op_write_yaml_file(TABULATOR_COUNT_FILE,tc,'Tabulator Count')
  when 'counter_count'
    cc = datum
    tc = op_instantiate_tabulator(tab, false)
    errs = tab.validate_counter_count(cc['counter_count'])
    print "Counter Count OK\n\n"
    tc = tab.update_tabulator_count(tc,cc)
    op_write_yaml_file(TABULATOR_COUNT_FILE,tc,'Tabulator Count')
    op_print_state(tab, tc, false)
  when 'tabulator_count'
    tc = datum
    errs = tab.validate_tabulator_count(tc['tabulator_count'])
    print "Tabulator Count OK\n\n"
  else
    print "Unknown tabulator file type: #{type}\n"
    exit(1)
  end
  op_print_warnings(errs, true)
end

def op_print_warnings(errs, short = false)
  warnings = errs[1]
  if (warnings.length > 0)
    print "There were #{warnings.length} WARNINGS!\n"
    warnings.each { |text| print "  ",text,"\n" } unless short
  end
end  

begin
  tab = false
  operator_print = false
  operator_trace = false
  file1 = ''
  file2 = ''
  ARGV.each do |arg|
    (arg == 'trace' ? (operator_trace = true) :
     (arg == 'print' ? (operator_print = true) :
      (file1 == '' ? (file1 = arg) : (file2 = arg))))
  end
  print "Trace ON\n" if operator_trace
  print "Print ON\n" if operator_print
  if (file1 == '' || file1 == 'help')
    operator_data() if operator_print
    operator_help() unless operator_print and file1 == ''
    exit(0)
  elsif (file1 == 'reset')
    operator_reset()
    exit(0)
  elsif (file1 == 'output')
    operator_data() if operator_print
    operator_output()
    exit(0)
  elsif (file1 == 'data')
    operator_data()
    exit(0)
  elsif (file1 == 'state')
    operator_state(true)
    exit(0)
  elsif (File.exists?(file1))
    tab = operator_file(file1, file2)
    operator_data(tab) if operator_print;
  else
    print "\nERROR, non-existent file: #{file1}\n\n"
  end
rescue 
  exit(1)
else
  exit(0)
end
