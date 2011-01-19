require "yaml"
require "tab_check_syntax"
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
  print "       \#   election definition: syntax checks, validates, installs\n"
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

def operator_output
  op_state_exit_initial()
  tc = op_instantiate_tabulator()
  lines = tabulator_spreadsheet()
  print "\nCSV Output:\n\n"
  print lines,"\n"
  outfile = File.open(tabulator_csv_file(), 'w')
  outfile.puts lines
  outfile.close()
end

def operator_data
  op_state_exit_initial()
  tc = op_instantiate_tabulator()
  print YAML::dump(tc),"\n"
  tabulator_dump_data()
end

def operator_state
  state = op_state_exit_initial()
  print "\nChecking Tabulator State\n\n"
  tc = op_instantiate_tabulator()
  if (tc['tabulator_count']['counter_count_list'].length == 0)
    print "\nNo counts accumulated so far\n"
    print "\nTabulator State: ",state,"\n\n"
    return
  end
  missing, unconids = op_state_donep(tc, true)
  print "\nTotal Missing Counts: #{missing}\n"
  label = ''
  if (missing == 0)
    print "\nTabulator State: DONE!"
    label = "   BUT??? ... \n\n  "
  else
    print "\nTabulator State: ",state
    label = "\n\n"
  end
  op_print_missing_contests(label, unconids)
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
  accumulated, unconids = tabulator_accumulated_counter_counts(tc)
  op_print_accumulated_counts(accumulated) if printit
  missing = op_find_missing_expected_counts(accumulated, printit)
  if (printit)
    [missing, unconids]
  else
    ((unconids.length) == 0 && (missing == 0))
  end
end

def op_find_missing_expected_counts(accumulated, printit)
  missing = 0
  print "\nMissing Counts:\n" if printit
  $precinct_counts.sort.each do |pid, v|
    pmissing = 0
    overdone = false
    print "  #{pid}: " if printit
    v.each do |cid, n|
      r = ((accumulated.key?(pid) && accumulated[pid].key?(cid)) ?
           accumulated[pid][cid] : 0)
      if ( r < n )
        print "\n" if printit && pmissing == 0
        print "    #{cid}: ", (n-r) ,"\n" if printit
        pmissing += n
      elsif (r > n)
        overdone = true
      end
    end
    print "Done\n" if printit && pmissing == 0 && ! overdone
    print "Overdone\n" if printit && pmissing == 0 && overdone
    missing += pmissing
  end
  missing
end

def op_print_missing_contests(label, unconids)
  if (unconids.length == 0)
    print "\n\n"
  else
    print label,"No reporting data on the following contests: "
    print unconids.inspect.gsub(/\"/,''),"\n\n"
  end
end

def op_print_accumulated_counts(accumulated)
  print "\nAccumulated Counts:\n"
  accumulated.sort.each do |pid, v|
    print "  #{pid}: \n"
    v.each { |cid, n| print "    #{cid}: ",n,"\n" }
  end
end

def op_instantiate_tabulator(printit = true)
  print "Instantiating Tabulator (Check Syntax, Validate)\n" if printit
  tcfile = tabulator_count_file()
  tc = op_read_yaml_file(tcfile)
  if (tc.is_a?(Hash) && (tc.keys.length == 1) &&
      (tc.keys[0] == 'tabulator_count'))
    schema_file = "Syntax/tabulator_count_schema.yml"
    schema = op_read_yaml_file(schema_file)
    if (check_syntax(schema, tc))
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

def op_check_syntax(file)
  if ((datum = op_read_yaml_file(file, 'data')) &&
      (datum.is_a?(Hash) && (datum.keys.length == 1)) &&
      (type = datum.keys[0]) && 
      (schema_file = "Syntax/#{type}_schema.yml") &&
      File.exists?(schema_file) &&
      (schema = op_read_yaml_file(schema_file, 'schema')) &&
      check_syntax(schema, datum))
    datum
  end
end

def operator_file(file)
  datum = op_check_syntax(file)
  if (! datum.is_a?(Hash))
    print "Unexpected contents of tabulator file: #{file}\n"
    exit(1)
  end
  op_state_exit_initial() if (datum.keys[0] == 'counter_count')
  print "Check Syntax: #{datum.keys[0]}: OK\n"
  print "Validating: #{datum.keys[0]}"
  type = datum.keys[0]
  case type
  when 'election_definition'
    ed = datum
    tabulator_initaliaze()
    tabulator_validate_election_definition(ed['election_definition'])
    print ": OK\n\n"
    tc = tabulator_new(ed['election_definition'])
    op_write_yaml_file(tabulator_count_file(),tc,'Tabulator Count')
  when 'counter_count'
    cc = datum
    tc = op_instantiate_tabulator(false)
    tabulator_check_duplicate_counter_count(cc['counter_count'])
    tabulator_validate_counter_count(cc['counter_count'])
    print ": OK\n\n"
    tabulator_gather_votes(cc['counter_count']['contest_count_list'],
                           cc['counter_count']['question_count_list'])
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
  operator_print = false
  file = ''
  ARGV.each do |arg|
    (arg == 'trace' ? ($check_syntax_trace = true) :
     (arg == 'print' ? (operator_print = true) : (file = arg)))
  end
  print "Trace ON\n" if $check_syntax_trace
  print "Print ON\n" if operator_print
  if (file == '' || file == 'help')
    operator_data() if operator_print
    operator_help() unless operator_print and file == ''
    exit(0)
  elsif (file == 'reset')
    operator_reset()
    exit(0)
  elsif (file == 'output')
    operator_data() if operator_print
    operator_output()
    exit(0)
  elsif (file == 'data')
    operator_data()
    exit(0)
  elsif (file == 'state')
    operator_data() if operator_print
    operator_state()
    exit(0)
  elsif (File.exists?(file))
    operator_file(file)
    operator_data() if operator_print;
  else
    print "\nERROR, non-existent file: #{file}\n\n"
  end
rescue UidErr, ShouldntErr
  op_print_warnings() if ($check_syntax_trace || operator_print)
  exit(1)
else
  op_print_warnings() if ($check_syntax_trace || operator_print)
  exit(0)
end
