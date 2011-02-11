#!/usr/bin/ruby

$LOAD_PATH << './Tabulator'

require "yaml"
require "fileutils"
require "check_syntax_yaml"
require "tabulator"

TABULATOR_COUNT_FILE = (File.directory?('Tabulator') ? 'Tabulator/' : '') +
  "TABULATOR_COUNT.yml"
                        
TABULATOR_RESET_FILE = (File.directory?('Tabulator') ? 'Tabulator/' : '') +
  "TABULATOR_BACKUP.yml"
                        
TABULATOR_CSV_FILE = (File.directory?('Tabulator') ? 'Tabulator/' : '') +
  "TABULATOR_COUNT.csv"

# Prints command-line help information.

def operator_help(detail = false)
  help_string_1d="
Note: [DEBUG] indicates a temporary/prototype command option.
"
  help_string_1 = "
Commands:

  ruby operator.rb       # basic command help information
  ruby operator.rb help  # detailed command help information
  ruby operator.rb reset # reset Tabulator to EMPTY state"
  help_string_2d = "
  ruby operator.rb [trace] ...  # [DEBUG] optionally turn on tracing"
  help_string_2 = "
  ruby operator.rb data  # print Tabulator dataset
  ruby operator.rb state # print Tabulator state: EMPTY, INITIAL,
                                 ACCUMULATING, or DONE  
  ruby operator.rb total # print Tabulator state, any missing counts,
                                 and voting results (CSV file)

  ruby operator.rb load <Jurisdiction_Def_File> <Election_Def_File>
"
  help_string_3d = "
     # The two files must contain, respectively, a Jurisdiction Definition
     # and an Election Definition.  Each is checked for proper syntax and
     # then validated, after which a zero-initialized Tabulator Count is
     # constructed and saved to file.  This command moves the state of the
     # Tabulator from EMPTY to INITIAL.
"

  help_string_3u = "
     # Process two Jurisdiction and Election Definition files to activate the
     # Tabulator, moving its state from EMPTY to INITIAL.
"
  help_string_4 = "
  ruby operator.rb add <Counter_Count_File>
"
  help_string_5d = "
     # The file contains a Counter Count, rejected if the state of the
     # Tabulator is EMPTY.  First the Tabulator is re-instantiated using the
     # current Tabulator Count file.  Then the Counter Count is checked for
     # proper syntax, validated, and incorporated into the Tabulator Count,
     # which is saved to file.  This command allows the Tabulator to
     # accumulate votes, and enter the ACCUMULATING state.  The Tabulator
     # remains in the ACCUMULATING state if expected counts are missing.  But
     # when the last expected count is processed, the Tabulator enters the
     # DONE state.
"
  help_string_5u = "
     # Process a Counter Count file to accumulate votes. If this is the last
     # expected count, the Tabulator moves into the DONE state, otherwise it
     # stays in the ACCUMULATING state.
"
  help_string_6d = "
  ruby operator.rb check [<Tabulator_Count_File>]

     # [DEBUG] The file contains a Tabulator Count (default Tabulator dataset
     # file used if unspecified).  It is checked for proper syntax and
     # validated.  This command is informational only and may be used to check
     # the consistency of the current Tabulator dataset file.
"
  help_string_6 = "
Tabulator dataset file: #{TABULATOR_COUNT_FILE}

"
  print help_string_1d if detail
  print help_string_1
  print help_string_2d if detail
  print help_string_2
  print help_string_3d if detail
  print help_string_3u unless detail
  print help_string_4
  print help_string_5d if detail
  print help_string_5u unless detail
  print help_string_6d if detail
  print help_string_6

end

# Resets the Tabulator state to EMPTY, by deleting all Tabulator Count
# files.

def operator_reset()
  print "Resetting Tabulator... "
  if (File.exists?(TABULATOR_COUNT_FILE))
    print "\n  Moving Tabulator Dataset (#{TABULATOR_COUNT_FILE}) to: " +
      "#{TABULATOR_RESET_FILE}\n"
    FileUtils.mv(TABULATOR_COUNT_FILE,TABULATOR_RESET_FILE)
  end
  if (File.exists?(TABULATOR_CSV_FILE))
    print "  Deleting Tabulator Spreadsheet: #{TABULATOR_CSV_FILE}\n"
    File.delete(TABULATOR_CSV_FILE)
  end
  print "Tabulator reset to EMPTY state\n"
end

# Prints the current Tabulator data set, by re-instantiating the Tabulator
# from the TABULATOR_COUNT_FILE, printing the file contents, and then dumping
# the contents of the Tabulator internal data structures.

def operator_data(tab = false, trace = false)
  if (tab)
    tab.tabulator_data()
  else
    ops_empty_state_noop()
    tab = ops_instantiate_tabulator(true, trace)
    tab.tabulator_data(true)
  end
end

# Prints to the TABULATOR_CSV_FILE (and STDOUT) a CSV spreadsheet representing
# the current set of voting results held by the Tabulator (stored in its
# TABULATOR_COUNT_FILE).

def operator_total(trace = false)
  ops_empty_state_noop()
  tab = ops_instantiate_tabulator(true, trace)
  state = operator_state(tab, trace)
  if (state == "ACCUMULATING" || state == "DONE")
    lines = tab.tabulator_spreadsheet()
    print "\nWriting Tabulator Spreadsheet: #{TABULATOR_CSV_FILE}\n"
    outfile = File.open(TABULATOR_CSV_FILE, "w")
    outfile.puts lines
    outfile.close()
    print "\nSpreadsheet Data (CSV Format):\n\n"
    print lines
  end
end

# Prints the current Tabulator state, by re-instantiating the Tabulator
# from the TABULATOR_COUNT_FILE, and then querying the Tabulator concerning
# its state.

def operator_state(tab = false, trace = false)
  ops_empty_state_noop()
  printit = (tab != false)
  tab = ops_instantiate_tabulator(true, trace) unless tab
  mystate = tab.tabulator_state
  state = mystate[0].split(/ /)[0]
  print "Tabulator State: #{mystate[0]}\n"
  if (printit && (state == "ACCUMULATING"))
    print "Missing Counts: Counter UID, Precinct UID, Reporting Group\n"
    missing = mystate[1]
    missing.each { |cid, rg, pid| print("  #{cid}, #{pid}, #{rg}\n") }
    print "Precincts Finished Reporting: "
    if (mystate[2].length == 0) 
      print "NONE\n"
    else
      print "#{mystate[2].inspect.gsub(/[\"\[\]]/,"")}\n"
    end
  end
  state
end

# Load the Jurisdiction and Election Definition files into the Tabulator.

def operator_load(jdfile = "", edfile = "", test = false, trace = false)
  unless (ops_empty_state?())
    print "Command ignored, non-EMPTY state, must reset first: load\n"
    exit(0)
  end
  jd = ops_file_process(jdfile, "Jurisdiction Definition", trace)
  ed = ops_file_process(edfile, "Election Definition", trace)
  tab = Tabulator.new(jd, ed, TABULATOR_COUNT_FILE)
  if (tab.validation_errors?)
    operator_warn(tab)
    print "Jurisdiction and Election Definitions: REJECTED\n"
    operator_state(tab, trace)
  else
    print "Validating Jurisdiction and Election Definitions: OK\n"
    operator_data(tab, trace)
    operator_warn(tab)
    reject = false
    unless (test)
      print "** ATTENTION ** ATTENTION **\n\n"
      print "Carefully examine the data above, then confirm approval to continue [y/n]: "
      answer = STDIN.gets.chomp
      reject = true unless (answer =~ /^[Yy]/)
    end
    if (reject)
      print "Jurisdiction and Election Definitions: REJECTED\n"
    else
      print "New Tabulator Initialized\n"
      ops_file_write_tabulator_count(tab)
    end
    operator_state(tab, trace)
  end
end

# Add the contents of a Counter Count file to the Tabulator state.

def operator_add(file = "", trace = false)
  ops_empty_state_noop("add")
  cc = ops_file_process(file, "Counter Count", trace)
  tab = ops_instantiate_tabulator(false, trace)
  tab.validate_counter_count(cc)
  tab.update_tabulator_count(cc)
  if (tab.validation_errors?)
    print "Validating Counter Count: ERRORS, DATA NOT ACCUMULATED\n"
  else
    print "Validating Counter Count: OK\n"
  end
  ops_file_write_tabulator_count(tab)
  operator_warn(tab)
  operator_state(tab, trace)
end

# Check the validity of a Tabulator Count file

def operator_check(file = "", trace = false)
  file = TABULATOR_COUNT_FILE if file == ""
  tc = ops_file_process(file, "Tabulator Count", trace)
  tab = Tabulator.new(false, false, false, tc)
  print "Validating Tabulator Count: OK\n" unless tab.validation_errors?
  operator_warn(tab)
  operator_state(tab, trace)
end

# Print any Tabulator error or warning messages.

def operator_warn(tab)
  tab.validation_errors.each { |text| print "** ERROR ** #{text}\n" }
  tab.validation_warnings.each { |text| print "** WARNING ** #{text}\n" }
end

# Prints an error message and dies.

def ops_die_error(message)
  print "** ERROR ** #{message}\n"
  exit(1)
end

# Prints a FATAL error message and dies.

def ops_die_fatal(message)
  print "** FATAL ERROR ** #{message}\n"
  exit(1)
end

# Returns <i>true</i> when the Tabulator state is EMPTY

def ops_empty_state?()
  ! File.exists?(TABULATOR_COUNT_FILE)
end
  
# If the Tabulator state is EMPTY, prints that fact and exits. For use by
# commands that are meaningless in this state: add, total, data

def ops_empty_state_noop(command = "")
  if (ops_empty_state?())
    print "Tabulator State: EMPTY (Waiting for Jurisdiction and Election Definitions)\n"
    print "Invalid command in EMPTY state: #{command}\n" unless command == ""
    exit(0)
  end
end

# Check the syntax of a file containing a Tabulator data set.  The file must
# contain a hash with a single key, where that key names a Tabulator schema.
# Either return the contents of the file or <i>false</> if there is an error.

def ops_file_process(file = "", label = "", trace = false)
  file = ops_file_prepend_path(file)
  ops_die_error("#{label} file not specified: #{label}") if file == ""
  ops_die_error("Non-existent #{label} file: #{file}") unless File.exists?(file)
  trace = (trace ? -300 : 300)
  if ((datum = ops_file_read(file, label)) &&
      (datum.is_a?(Hash) && (datum.keys.length == 1)) &&
      (type = datum.keys[0]) && 
      (schema_file = ops_file_prepend_path("Schemas/#{type}_schema.yml")) &&
      File.exists?(schema_file) &&
      (schema = ops_file_read(schema_file, "Schema")) &&
      CheckSyntaxYaml.new.check_syntax(schema, datum, true, trace).length == 0)
    print "Check Syntax of #{label} (#{file}): OK\n"
    datum
  else
    ops_die_error("Invalid contents of #{label} file: #{file}")
    false
  end
end

# Temporary means of running operator.rb from the directory above which it
# normally resides, by checking the current directory and optionally
# prepending "Tabulator/" to file names if the directory contains a Tabulator
# subdirectory.  FIX THIS...JVC

def ops_file_prepend_path(file)
  ((File.directory?('Tabulator') && (! (file =~ /^Tabulator/))) ?
   'Tabulator/' : '') + file
end

# Read a Tabulator data set from a file.

def ops_file_read(file, label = "")
  file = ops_file_prepend_path(file)
  print "Reading #{label}: #{file}\n" if (label != "")
  File.open(file) { |infile| YAML::load(infile) }
end

# Write a Tabulator data set to a file.

def ops_file_write_tabulator_count(tab)
  file = ops_file_prepend_path(TABULATOR_COUNT_FILE)
  print "Writing Tabulator Count: #{file}\n"
  File.open(file, "w") { |outfile| YAML::dump(tab.tabulator_count, outfile) }
end

# Instantiate the Tabulator using the Tabulator Count kept in the
# TABULATOR_COUNT_FILE.  Any error during this process is FATAL.  Returns the
# resulting Tabulator object.

def ops_instantiate_tabulator(printit = true, trace = false)
  tcfile = TABULATOR_COUNT_FILE
  tc = ops_file_read(tcfile)
  if (tc.is_a?(Hash) && (tc.keys.length == 1) &&
      (tc.keys[0] == "tabulator_count"))
    schema_file = "Schemas/tabulator_count_schema.yml"
    schema = ops_file_read(schema_file)
    trace = (trace ? -300 : 300)
    if (CheckSyntaxYaml.new.check_syntax(schema, tc, true, trace).length == 0)
      tab = Tabulator.new(false, false, false, tc)
      if (tab.validation_errors?)
        operator_warn(tab)
        ops_die_fatal("Errors Instantiating Tabulator from #{tcfile}", tab)
      end
    else
      ops_die_fatal("Syntax Check Failure on #{tcfile}")
    end
  else
    ops_die_fatal("Invalid Contents of #{tcfile}, Must Reset")
  end
  tab
end

# Command-line interface to Tabulator.
#
# For help type: ruby operator.rb
#            or: ruby operator.rb help

begin
  test = false
  if (ARGV.length > 1 && ARGV[0] == "test")
    test = true
    ARGV.shift
  end
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
      operator_help(true)
    when "reset"
      operator_reset()
    when "total"
      operator_total(trace)
    when "data"
      operator_data(false, trace)
    when "state"
      operator_state(false, trace)
    when "load"
      operator_load((ARGV.length > 1 ? ARGV[1] : ""),
                    (ARGV.length > 2 ? ARGV[2] : ""), test, trace)
    when "add"
      operator_add((ARGV.length > 1 ? ARGV[1] : ""), trace)
    when "check"
      operator_check((ARGV.length > 1 ? ARGV[1] : ""), trace)
    else
      print "Invalid Tabulator Command: #{ARGV.join(" ")}\n"
    end
  end
end
