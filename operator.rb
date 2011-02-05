#!/usr/bin/ruby

$LOAD_PATH << './Tabulator'

require "yaml"
require "check_syntax_yaml"
require "tabulator"

TABULATOR_COUNT_FILE = (File.directory?('Tabulator') ? 'Tabulator/' : '') +
  "TABULATOR_COUNT.yml"
                        
TABULATOR_CSV_FILE = (File.directory?('Tabulator') ? 'Tabulator/' : '') +
  "TABULATOR_COUNT.csv"

# Prints command-line help information.

def operator_help
  help_string = "
Note: [DEBUG] indicates a temporary/prototype command option.

Commands:

  ruby operator.rb              # same as help
  ruby operator.rb help         # print command help information
  ruby operator.rb reset        # reset Tabulator to INITIAL state
  ruby operator.rb [trace] ...  # [DEBUG] optionally turn on tracing
  ruby operator.rb data         # [DEBUG] print internal data structures
  ruby operator.rb spreadsheet  # print CSV spreadsheet with voting results
  ruby operator.rb state        # print Tabulator state, either INITIAL,
                                    ACCUMULATING, or DONE

  ruby operator.rb <Jurisdiction_Definition_File> <Election_Definition_File>

       # The two files must contain, respectively, a Jurisdiction Definition
       # and an Election Definition.  Each is checked for proper syntax and
       # then validated, after which a zero-initialized Tabulator Count is
       # constructed and saved to file.  This command moves the state of the
       # Tabulator from INITIAL to ACCUMULATING.

  ruby operator.rb <Counter_Count_File>

       # The file contains a Counter Count, rejected if the state of the
       # Tabulator is INITIAL.  First the Tabulator is re-instantiated using
       # the current Tabulator Count file.  Then the Counter Count is checked
       # for proper syntax, validated, and incorporated into the Tabulator
       # Count, which is saved to file.  This command allows the Tabulator to
       # accumulate votes.  The Tabulator remains in the ACCUMULATING state if
       # expected counts are missing.  But when the last expected count is
       # processed, the Tabulator enters the DONE state.

  ruby operator.rb <Tabulator_Count_File>

       # [DEBUG] The file contains a Tabulator Count.  It is checked for
       # proper syntax and validated.  This command is informational only and
       # is used to check the consistency of the current Tabulator Count file.

The file #{TABULATOR_COUNT_FILE} holds the current Tabulator Count data set.

"
  print help_string
end

# Resets the Tabulator state to INITIAL, by deleting all Tabulator Count
# files.

def operator_reset
  print "\nTabulator RESET..."
  once = false
  if (File.exists?(TABULATOR_COUNT_FILE))
    print " Deleting Tabulator Count: #{TABULATOR_COUNT_FILE}\n"
    File.delete(TABULATOR_COUNT_FILE)
    once = true
  end
  if (File.exists?(TABULATOR_CSV_FILE))
    print "  Deleting Tabulator Spreadsheet: #{TABULATOR_CSV_FILE}\n"
    File.delete(TABULATOR_CSV_FILE)
    once = true
  end
  print " Nothing to Do\n" unless once
  print "\n"
end

# Prints the current Tabulator data set, by re-instantiating the Tabulator
# from the TABULATOR_COUNT_FILE, printing the file contents, and then dumping
# the contents of the Tabulator internal data structures.

def operator_data(trace = false)
  ops_exit_if_initial_state("data")
  tab = ops_instantiate_tabulator(true, trace)
  tc = tab.tabulator_count
  tab.tabulator_dump_data()
  tab
end

# Prints to the TABULATOR_CSV_FILE (and STDOUT) a CSV spreadsheet representing
# the current set of voting results held by the Tabulator (stored in its
# TABULATOR_COUNT_FILE).

def operator_spreadsheet(trace = false)
  ops_exit_if_initial_state("spreadsheet")
  tab = ops_instantiate_tabulator(true, trace)
  lines = tab.tabulator_spreadsheet()
  print "Writing Tabulator Spreadsheet: #{TABULATOR_CSV_FILE}\n"
  outfile = File.open(TABULATOR_CSV_FILE, "w")
  outfile.puts lines
  outfile.close()
  print "\nSpreadsheet Data (CSV Format):\n\n"
  print lines
end

# Prints the current Tabulator state, by re-instantiating the Tabulator
# from the TABULATOR_COUNT_FILE, and then querying the Tabulator concerning
# its state.

def operator_state(tab = false, tc = false, printit = false, trace = false)
  ops_exit_if_initial_state("")
  tab = ops_instantiate_tabulator(true, trace) unless tab
  tc = tab.tabulator_count unless tc
  mystate = tab.tabulator_state(tc)
  ops_die_error("Tabulator State Not Array: #{mystate.inspect}", true) unless
    mystate.is_a?(Array)
  state = mystate[0]
  print "Tabulator State: #{state}\n"
  if (printit && state =~ /^ACCUM/)
    print "Missing Counts:\n"
    missing = mystate[1]
    missing.each { |cid, rg, pid|
      print "  Counter: #{cid}, Precinct: #{pid}, Reporting Group: #{rg}\n" }
  end
end  

# Process the file(s) that were provided as arguments.

def operator_file(file1, file2, trace = false)
  file1 = ops_prepend_path(file1)
  ops_die_error("Non-existent file: #{file1}") unless File.exists?(file1)
  datum = ops_check_syntax(file1, trace)
  ops_die_error("Invalid contents of file: #{file1}") unless datum
  ops_exit_if_initial_state("Counter Count Accumulation") if (datum.keys[0] == "counter_count")
  ops_print_check_syntax(datum.keys[0], file1)
  type = datum.keys[0]
  case type
  when "election_definition"
    ops_die_error("Election Definition must be second argument, not first")
  when "jurisdiction_definition"
    jd = datum
    file2 = ops_prepend_path(file2)
    ops_die_error("Election Definition file name not provided") if file2 == ""
    ops_die_error("Election Definition file non-existent: #{file2}") unless 
      File.exists?(file2)
    datum = ops_check_syntax(file2, trace)
    ed = datum
    ops_die_error("Invalid contents of Election Definition file: #{file2}") if
      (! datum.is_a?(Hash) || datum.keys[0] != "election_definition")
    ops_print_check_syntax(datum.keys[0], file2)
    print "Validating Jurisdiction and Election Definitions:"
    tab = Tabulator.new(jd, ed, TABULATOR_COUNT_FILE)
    tc = tab.tabulator_count
    errors = tab.validation_errors()
    if (errors.length == 0)
      print " OK\n"
      ops_write_yaml_file(TABULATOR_COUNT_FILE, tc, "Tabulator Count", true)
    end
    ops_print_errs(tab, true)
  when "counter_count"
    cc = datum
    tab = ops_instantiate_tabulator(false, trace)
    tc = tab.tabulator_count
    print "Validating Counter Count:"
    tab.validate_counter_count(cc)
    errors = tab.validation_errors()
    if (tab.validation_errors().length == 0)
      print " OK\n"
      tc = tab.update_tabulator_count(tc, cc)
      ops_write_yaml_file(TABULATOR_COUNT_FILE,tc,"Tabulator Count",true)
      operator_state(tab, tc, false, trace)
    end
    ops_print_errs(tab, true)
  when "tabulator_count"
    tc = datum
    print "Validating: Tabulator Count\n"
    tab = Tabulator.new(false, false, false, tc)
    errors = tab.validation_errors()
    if (errors.length == 0)
      print "Tabulator Count OK\n\n"
    end
    ops_print_errs(tab, true)
  else
    print "Unknown tabulator file type: #{type}\n"
  end
end

# If the Tabulator is in its INITIAL state, prints that fact and exits. For
# use by commands that are meaningless in this state, such as "data" or
# "spreadsheet".

def ops_exit_if_initial_state(command = "")
  if (!File.exists?(TABULATOR_COUNT_FILE))
    print "Tabulator State: INITIAL (Waiting for Jurisdiction and Election Definitions)\n"
    print "Command Ignored: #{command}\n\n" unless command == ""
    exit(0)
  end
end

# Instantiate the Tabulator using the Tabulator Count kept in the
# TABULATOR_COUNT_FILE.  Any error during this process is FATAL.  Returns the
# resulting Tabulator object.

def ops_instantiate_tabulator(printit = true, trace = false)
  print "Instantiating Tabulator:"
  tcfile = TABULATOR_COUNT_FILE
  tc = ops_read_yaml_file(tcfile)
  if (tc.is_a?(Hash) && (tc.keys.length == 1) &&
      (tc.keys[0] == "tabulator_count"))
    schema_file = "Schemas/tabulator_count_schema.yml"
    schema = ops_read_yaml_file(schema_file)
    trace = (trace ? -300 : 300)
    if (CheckSyntaxYaml.new.check_syntax(schema, tc, true, trace).length == 0)
      tab = Tabulator.new(false, false, false, tc)
    else
      ops_die_error("Syntax Check Failure on #{tcfile}", true)
    end
  else
    ops_die_error("Invalid Contents of #{tcfile}, Must Reset", true)
  end
  if (tab.validation_errors().length == 0)
    print " OK\n"
  else
    ops_die_error("Errors Instantiating Tabulator from #{tcfile}", true, tab)
  end
  tab
end

# Read a Tabulator data set from a file.

def ops_read_yaml_file(file, label = "", trace = false)
  file = ops_prepend_path(file)
  print "Reading #{label}: #{file}\n" if (label != "" && trace)
  File.open(file) { |infile| YAML::load(infile) }
end

# Write a Tabulator data set to a file.

def ops_write_yaml_file(file, datum, label = "", trace = false)
  file = ops_prepend_path(file)
  print "Writing #{label}: #{file}\n\n" if (label != "" && trace)
  File.open(file, "w") { |outfile| YAML::dump(datum, outfile) }
end

# Temporary means of running operator.rb from the directory above which it
# normally resides, by checking the current directory and optionally
# prepending "Tabulator/" to file names if the directory contains a Tabulator
# subdirectory.  FIX THIS...JVC

def ops_prepend_path(file)
  ((File.directory?('Tabulator') && (! (file =~ /^Tabulator/))) ?
   'Tabulator/' : '') + file
end

# Check the syntax of a file containing a Tabulator data set.  The file must
# contain a hash with a single key, where that key names a Tabulator schema.
# Either return the contents of the file or <i>false</> if there is an error.

def ops_check_syntax(file, trace = false)
  trace = (trace ? -300 : 300)
  file = ops_prepend_path(file)
  if ((datum = ops_read_yaml_file(file, "data")) &&
      (datum.is_a?(Hash) && (datum.keys.length == 1)) &&
      (type = datum.keys[0]) && 
      (schema_file = ops_prepend_path("Schemas/#{type}_schema.yml")) &&
      File.exists?(schema_file) &&
      (schema = ops_read_yaml_file(schema_file, "schema")) &&
      CheckSyntaxYaml.new.check_syntax(schema, datum, true, trace).length == 0)
    datum
  else
    false
  end
end

# Prints that a successful syntax check has just occurred.

def ops_print_check_syntax(type, file)
  file = ops_prepend_path(file)
  trans = {"jurisdiction_definition"=>"Jurisdiction Definition",
    "election_definition"=>"Election Definition",
    "counter_count"=>"Counter Count",
    "tabulator_count"=>"Tabulator Count"}
  type = trans[type] if (trans.keys.include?(type))
  print "Check Syntax of #{type} (#{file}): OK\n"
end

# Prints an error message and dies.  Optionally indicates the error is FATAL,
# and optionally prints the current set of Tabulator error/warning messages.

def ops_die_error(message, fatal = false, tab = false)
  if (fatal)
    print "** FATAL ERROR ** #{message}\n"
  else
    print "** ERROR ** #{message}\n"
  end
  ops_print_errs(tab) if tab
  exit(1)
end

# Print any Tabulator error or warning messages.

def ops_print_errs(tab, short = false)
  errors = tab.validation_errors()
  if (errors.length > 0)
    print "\n\nThere were ERRORS! (#{errors.length})\n"
    errors.each { |text| print "** ERROR ** ",text,"\n" }
  else
    print "There were NO ERRORS!\n" unless short
  end
  warnings = tab.validation_warnings()
  if (warnings.length > 0)
    print "\n" if (errors.length == 0) and !short
    print "There were WARNINGS! (#{warnings.length})\n"
    warnings.each { |text| print "** WARNING ** ",text,"\n" }
  else
    print "There were NO WARNINGS!\n" unless short
  end
  print "\n" if ((errors.length > 0) || (warnings.length > 0))
end

# Command-line interface to Tabulator.
#
# For help type: ruby operator.rb
#            or: ruby operator.rb help

begin
  trace = false
  if (ARGV.length > 1 && ARGV[0] == "trace")
    trace = true
    ARGV.shift
  end
  if (ARGV.length == 0)
    operator_help()
  else 
    case ARGV[0]
    when "help"
      operator_help()
    when "reset"
      operator_reset()
    when "spreadsheet"
      operator_spreadsheet(trace)
    when "data"
      operator_data(trace)
    when "state"
      operator_state(false, false, true, trace)
    else
      operator_file(ARGV[0], (ARGV.length > 1 ? ARGV[1] : ""), trace)
    end
  end
end
