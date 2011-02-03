#!/usr/bin/ruby

$LOAD_PATH << './Tabulator'

require "yaml"
require "check_syntax_yaml"
require "tabulator"

TABULATOR_COUNT_FILE = (File.directory?('Tabulator') ? 'Tabulator/' : '') +
  "TABULATOR_COUNT.yml"
                        
TABULATOR_CSV_FILE = (File.directory?('Tabulator') ? 'Tabulator/' : '') +
  "TABULATOR_COUNT.csv"

def operator_help
  print "\nCommands:\n\n"
  print "  ruby operator.rb          \# same as help\n"
  print "  ruby operator.rb help     \# print help info\n"
  print "  ruby operator.rb reset    \# reset Tabulator\n"
  print "  ruby operator.rb output   \# print CSV voting results\n"
  print "  ruby operator.rb data     \# print Tabulator data structures\n"
  print "  ruby operator.rb state    \# print Tabulator state\n\n"
  print "  ruby operator.rb [trace] [print] <FILE1> [<FILE2>]\n\n"
  print "       \# trace: optional arg turns on debug tracing\n"
  print "       \# print: optional arg prints data structures afterwards\n"
  print "       \#\n"
  print "       \# <FILE1>: a YAML file containing ...\n"
  print "       \#   counter count: syntax checks, validates, updates tabulator\n"
  print "       \#   tabulator count: syntax checks, validates\n"
  print "       \#\n"
  print "       \# <FILE1> <FILE2>: two YAML files containing ...\n"
  print "       \#   jurisdiction definition: syntax checks, validates, installs\n"
  print "       \#   election definition: syntax checks, validates, installs\n\n"
end

def operator_reset
  print "\nTabulator RESET..."
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
  if (once)
    print "\n"
  else
    print " Nothing To Do\n\n"
  end
end

def operator_output(trace = false)
  op_exit_initial()
  tab = op_instantiate_tabulator(true, trace)
  tc = tab.tabulator_count
  lines = tab.spreadsheet_for_tabulator()
  print "\nCSV Output:\n\n"
  print lines,"\n"
  outfile = File.open(tabulator_csv_file(), "w")
  outfile.puts lines
  outfile.close()
end

def operator_data(trace = false)
  op_exit_initial()
  tab = op_instantiate_tabulator(true, trace)
  tc = tab.tabulator_count
  tab.dump_tabulator_data(tc)
  tab
end

def operator_state(printit = false, trace = false)
  print "\nChecking Tabulator State\n\n"
  op_exit_initial()
  tab = op_instantiate_tabulator(true, trace)
  tc = tab.tabulator_count
  op_print_state(tab, tc, printit)
end

def op_print_state(tab, tc, printit)
  mystate = tab.current_tabulator_state(tc)
  if (!mystate.is_a?(Array))
    print "Tabulator State Not An Array: #{mystate.inspect}\n"
    exit(1)
  end
  state = mystate[0]
  print "Tabulator State: #{state}\n"
  if (printit && state =~ /^ACCUM/)
    print "Missing Counts:\n"
    missing = mystate[1]
    missing.each { |cid, rg, pid|
      print "  Counter: #{cid}, Precinct: #{pid}, Reporting Group: #{rg}\n" }
  end
  print "\n"
end  

def op_exit_initial()
  if (!File.exists?(TABULATOR_COUNT_FILE))
    print "\nTabulator State: INITIAL (Waiting for Jurisdiction and Election Definitions)\n"
    exit(0)
  end
end

def op_instantiate_tabulator(printit = true, trace = false)
  print "Instantiating Tabulator:"
  tcfile = TABULATOR_COUNT_FILE
  tc = op_read_yaml_file(tcfile)
  if (tc.is_a?(Hash) && (tc.keys.length == 1) &&
      (tc.keys[0] == "tabulator_count"))
    schema_file = "Schemas/tabulator_count_schema.yml"
    schema = op_read_yaml_file(schema_file)
    trace = (trace ? -300 : 300)
    if (CheckSyntaxYaml.new.check_syntax(schema, tc, true, trace).length == 0)
      tab = Tabulator.new(false, false, false, tc)
    else
      print "\n** FATAL ERROR ** Syntax check failure on Tabulator Count file #{tcfile}\n"
      exit(1)
    end
  else
    print "\n** FATAL ERROR ** Invalid Tabulator Count file #{tcfile}, must RESET\n"
    exit(1)
  end
  errors = tab.validation_errors()
  if (errors.length == 0)
    print " OK\n"
  else
    print "\n** FATAL ERROR ** Instantiating Tabulator from Tabulator Count file\n"
    op_print_errs(tab)
    exit(1)
  end
  tab
end

def op_read_yaml_file(file, label = "", trace = false)
  file = op_prepend(file)
  print "Reading #{label} file: #{file}\n" if (label != "" && trace)
  File.open(file) { |infile| YAML::load(infile) }
end

def op_write_yaml_file(file, datum, label = "", trace = false)
  file = op_prepend(file)
  print "Writing #{label} file: #{file}\n" if (label != "" && trace)
  File.open(file, "w") { |outfile| YAML::dump(datum, outfile) }
end

def op_prepend(file)
  ((File.directory?('Tabulator') && (! (file =~ /^Tabulator/))) ?
   'Tabulator/' : '') + file
end

def op_check_syntax(file, trace = false)
  trace = (trace ? -300 : 300)
  file = op_prepend(file)
  if ((datum = op_read_yaml_file(file, "data")) &&
      (datum.is_a?(Hash) && (datum.keys.length == 1)) &&
      (type = datum.keys[0]) && 
      (schema_file = op_prepend("Schemas/#{type}_schema.yml")) &&
      File.exists?(schema_file) &&
      (schema = op_read_yaml_file(schema_file, "schema")) &&
      CheckSyntaxYaml.new.check_syntax(schema, datum, true, trace).length == 0)
    datum
  else
    false
  end
end

def op_print_check_syntax(type, file)
  file = op_prepend(file)
  trans = {"jurisdiction_definition"=>"Jurisdiction Definition",
    "election_definition"=>"Election Definition",
    "counter_count"=>"Counter Count",
    "tabulator_count"=>"Tabulator Count"}
  type = trans[type] if (trans.keys.include?(type))
  print "Check Syntax of #{type} (#{file}): OK\n"
end

def operator_file(file1, file2, trace = false)
  datum = op_check_syntax(file1, trace)
  unless (datum)
    print "Unexpected contents of file: #{file1}\n"
    exit(1)
  end
  op_exit_initial() if (datum.keys[0] == "counter_count")
  op_print_check_syntax(datum.keys[0], file1)
  type = datum.keys[0]
  case type
  when "election_definition"
    print "Election Definition must be preceeded by Jurisdiction Definition\n"
    exit(1)
  when "jurisdiction_definition"
    jd = datum
    if (file2 == "" || ! File.exists?(op_prepend(file2)))
      print "Jurisdiction file must be followed by Election Definition file: #{file2}\n"
      exit(1)
    end
    datum = op_check_syntax(file2, trace)
    ed = datum
    if (! datum.is_a?(Hash) || datum.keys[0] != "election_definition")
      print "Unexpected contents of Election Definition file: #{file2}\n"
      exit(1)
    end
    op_print_check_syntax(datum.keys[0], file2)
    print "Validating Jurisdiction Definition and Election Definitions:"
    tab = Tabulator.new(jd, ed, TABULATOR_COUNT_FILE)
    tc = tab.tabulator_count
    errors = tab.validation_errors()
    if (errors.length == 0)
      print " OK\n"
      op_write_yaml_file(TABULATOR_COUNT_FILE,tc,"Tabulator Count", true)
    end
    op_print_errs(tab, true)
  when "counter_count"
    cc = datum
    tab = op_instantiate_tabulator(false, trace)
    tc = tab.tabulator_count
    print "Validating Counter Count:"
    tab.validate_counter_count(cc)
    errors = tab.validation_errors()
    if (tab.validation_errors().length == 0)
      print " OK\n"
      tc = tab.update_tabulator_count(tc, cc)
      op_write_yaml_file(TABULATOR_COUNT_FILE,tc,"Tabulator Count",true)
      op_print_state(tab, tc, false)
    end
    op_print_errs(tab, true)
  when "tabulator_count"
    tc = datum
    print "Validating: Tabulator Count\n"
    tab = Tabulator.new(false, false, false, tc)
    errors = tab.validation_errors()
    if (errors.length == 0)
      print "Tabulator Count OK\n\n"
    end
    op_print_errs(tab, true)
  else
    print "Unknown tabulator file type: #{type}\n"
  end
end

def op_print_errs(tab, short = false)
  errors = tab.validation_errors()
  if (errors.length > 0)
    print "\n\nThere were ERRORS! (#{errors.length})\n"
    errors.each { |text| print "** ERROR ** ",text,"\n" }
  else
    print "There were NO ERRORS!\n" unless short
  end
  warnings = tab.validation_warnings()
  if (warnings.length > 0)
    print "\n" if (errors.length == 0)
    print "There were WARNINGS! (#{warnings.length})\n"
    warnings.each { |text| print "** WARNING ** ",text,"\n" }
  else
    print "There were NO WARNINGS!\n" unless short
  end
  print "\n" if ((errors.length > 0) || (warnings.length > 0))
end  

begin
  tab = false
  operator_print = false
  operator_trace = false
  file1 = ""
  file2 = ""
  ARGV.each do |arg|
    (arg == "trace" ? (operator_trace = true) :
     (arg == "print" ? (operator_print = true) :
      (file1 == "" ? (file1 = arg) : (file2 = arg))))
  end
  print "Trace ON\n" if operator_trace
  print "Print ON\n" if operator_print
  if (file1 == "" || file1 == "help")
    operator_data(operator_trace) if operator_print
    operator_help() unless operator_print and file1 == ""
    exit(0)
  elsif (file1 == "reset")
    operator_reset()
    exit(0)
  elsif (file1 == "output")
    if (operator_print)
      operator_data(operator_trace)
      operator_output()
    else
      operator_output(operator_trace)
    end
    exit(0)
  elsif (file1 == "data")
    operator_data(operator_trace)
    exit(0)
  elsif (file1 == "state")
    operator_state(true, operator_trace)
    exit(0)
  elsif (File.exists?(op_prepend(file1)))
    operator_file(file1, file2, operator_trace)
    operator_data(operator_trace) if operator_print;
  else
    print "\nERROR, non-existent file: #{file1}\n\n"
  end
rescue 
  exit(1)
else
  exit(0)
end
