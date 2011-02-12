#!/usr/bin/ruby

# OSDV Tabulator - TTV Tabulator Validation of Election Datasets
# Author: Jeff Cook
# Date: 1/20/2011
#
# License Version: OSDV Public License 1.2
#
# The contents of this file are subject to the OSDV Public License
# Version 1.2 (the "License"); you may not use this file except in
# compliance with the License. You may obtain a copy of the License at
# http://www.osdv.org/license/
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
# License for the specific language governing rights and limitations
# under the License.

# The Original Code is: TTV Tabulator.
# The Initial Developer of the Original Code is Open Source Digital Voting Foundation.
# Portions created by Open Source Digital Voting Foundation are Copyright (C) 2010, 2011.
# All Rights Reserved.

# Contributors: Jeff Cook

$LOAD_PATH << './Tabulator'

require "yaml"
require "fileutils"
require "check_syntax_yaml"
require "tabulator"

class Operator

  TABULATOR_COUNT_FILE =  "TABULATOR_COUNT.yml"
                        
  TABULATOR_BACKUP_FILE = "TABULATOR_BACKUP.yml"

  TABULATOR_CSV_FILE =    "TABULATOR_SPREADSHEET.csv"

# Arguments:
# * <i>detail</i> (<i>Boolean</i>) whether to print detailed help information (optional)
#
# Returns: N/A
#
# Implements the "help" command.  Prints simple or detailed help information
# about all the Operator commands.

  def help(detail = false)
    help_string_1d="
Note: [DEBUG] indicates a temporary/prototype command option.
"
    help_string_1 = "
Commands:

  ruby operator.rb       # basic command help information
  ruby operator.rb help  # detailed command help information
  ruby operator.rb reset # reset Tabulator to EMPTY state"
    help_string_2 = "
  ruby operator.rb data  # print Tabulator data
  ruby operator.rb state # print Tabulator state: 
                              EMPTY, INITIAL, ACCUMULATING, or DONE  
  ruby operator.rb total # print Tabulator state, any missing counts, and
                              voting results spreadsheet (CSV file)

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
     # Process two Jurisdiction and Election Definition files to initialize
     # the Tabulator, moving its state from EMPTY to INITIAL.
"
    help_string_4 = "
  ruby operator.rb add <Counter_Count_File>
"
    help_string_5d = "
     # The file contains a Counter Count, rejected if the state of the
     # Tabulator is EMPTY.  First the Tabulator is re-instantiated using the
     # current Tabulator data file.  Then the Counter Count is checked for
     # proper syntax, validated, and incorporated into the Tabulator dataset,
     # which is saved to file.  This command allows the Tabulator to
     # accumulate votes, and enter the ACCUMULATING state. When the last
     # expected count is accumulated, the Tabulator enters the DONE state.
"
    help_string_5u = "
     # Process a Counter Count file to accumulate votes.  The Tabulator state
     # becomes ACCUMULATING, unless this is the last expected count, in which
     # case the Tabulator state is DONE.
"
    help_string_6d = "
  ruby operator.rb check [<Tabulator_Count_File>]

     # [DEBUG] The file contains a Tabulator Count (the default Tabulator data
     # file used if the file is left unspecified).  It is checked for proper
     # syntax and validated.  This command is informational only and may be
     # used to check the consistency of the current Tabulator data file.
"
    help_string_6 = "
xop_Tabulator data file: #{xop_file_prepend(TABULATOR_COUNT_FILE)}

"
    print help_string_1d if detail
    print help_string_1
    print help_string_2
    print help_string_3d if detail
    print help_string_3u unless detail
    print help_string_4
    print help_string_5d if detail
    print help_string_5u unless detail
    print help_string_6d if detail
    print help_string_6
  end

# No Arguments
#
# Returns: N/A
#
# Implements the "reset" command.  Resets the Tabulator state to
# EMPTY, by backing up the contents of (moving) the Tabulator data file from
# <tt><b>TABULATOR_COUNT_FILE</b></tt> to
# <tt><b>TABULATOR_BACKUP_FILE</b></tt>.

  def reset()
    tc_file = xop_file_prepend(TABULATOR_COUNT_FILE)
    if (xop_file_exist?(tc_file))
      xop_file_backup(tc_file)
      print "Tabulator reset to EMPTY state.\n"
    else
      print "Nothing to do, Tabulator already in EMPTY state.\n"
    end
  end

# Arguments:
# * <i>tab</i> (<i>Class Object</i>) Tabulator object (optional)
#
# Returns: N/A
#
# Implements the "data" command, which is a no-op if the Tabulator is in the
# EMPTY state.  Prints Tabulator data using either the optional Tabulator
# object (<i>tab</i>) provided as input or by re-instantiating the Tabulator
# from the contents of its persistent data file
# <tt><b>TABULATOR_COUNT_FILE</b></tt>.

  def data(tab = false)
    if (tab != false)
      tab.tabulator_data()
    else
      xop_empty_state_no_op()
      tab = xop_instantiate()
      tab.tabulator_data(true)
    end
  end

# Arguments:
# * <i>tab</i> (<i>Class Object</i>) Tabulator object (optional)
# * <i>details</i> (<i>Boolean</i>) whether to print details about the state (optional)
#
# Returns: N/A
#
# Implements the "state" command.  Prints the Tabulator state either using the
# optional Tabulator object (<i>tab</i>) provided as input or by
# re-instantiating the Tabulator from its persistent data file
# <tt><b>TABULATOR_COUNT_FILE</b></tt>.  If indicated, print details
# concerning the missing counts.

  def state(tab = false, details = false)
    xop_empty_state_no_op()
    tab = xop_instantiate() unless tab
    mystate = tab.tabulator_state
    state = mystate[0].split(/ /)[0]
    print "Tabulator State: #{mystate[0]}\n"
    if (details && (state == "ACCUMULATING"))
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

# No Arguments
#
# Returns: N/A
#
# Implements the "total" command.  Re-instantiates the Tabulator from its
# persistent data file <tt><b>TABULATOR_COUNT_FILE</b></tt>, prints out
# detailed state information, then produces a CSV spreadsheet containing the
# current set of voting results, which it writes to
# <tt><b>TABULATOR_CSV_FILE</b></tt> and prints to STDOUT.

  def total()
    xop_empty_state_no_op()
    tab = xop_instantiate()
    if (["ACCUMULATING", "DONE"].include?(state(tab, true)))
      lines = tab.tabulator_spreadsheet()
      csv_file = xop_file_prepend(TABULATOR_CSV_FILE)
      print "\nWriting Tabulator Spreadsheet: #{csv_file}\n"
      outfile = xop_file_open_write(csv_file)
      outfile.puts lines
      outfile.close()
      print "\nSpreadsheet Data (CSV Format):\n\n"
      print lines
    end
  end
  
# Arguments:
# * <i>jd_file</i> (<i>String</i>) Jurisdiction Definition (JD) File
# * <i>ed_file</i> (<i>String</i>) Election Definition (JD) File
# * <i>test</i> (<i>Boolean</i>) indicates whether to accept validity without asking (optional, for testing)
#
# Returns: N/A
#
# Implements the "load" command, which is a no-op unless the Tabulator is in
# the EMPTY state.  Processes the JD and ED files, checking them for
# existence, correct syntax, and validity.  Any Tabulator validation errors
# cause them to be rejected, otherwise they may be used to create a new
# initial Tabulator dataset.  In testing mode (<i>test</i> is <i>true</i>),
# they are used without question.  Otherwise, the operator is shown a data
# summary, asked for confirmation, and they are used only if approved.

  def load(jd_file, ed_file, test = false)
    unless (xop_empty_state?())
      print "Command \"load\" ignored in non-EMPTY state, must reset first.\n"
      exit(0)
    end
    jd = xop_file_process(jd_file, "Jurisdiction Definition")
    ed = xop_file_process(ed_file, "Election Definition")
    tc_file = xop_file_prepend(TABULATOR_COUNT_FILE)
    tab = xop_new_tabulator(jd, ed, tc_file, false)
    if (tab.validation_errors?)
      xop_warn(tab)
      print "Jurisdiction and Election Definitions: REJECTED\n"
    else
      print "Validating Jurisdiction and Election Definitions: OK\n\n"
      data(tab)
      xop_warn(tab)
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
        xop_file_write(tab)
        state(tab)
        print "\n"
      end
    end
  end

# Arguments:
# * <i>cc_file</i>: (<i>String</i>) Counter Count file name
#
# Returns: N/A
#
# Implements the "add" command, which is a no-op if the Tabulator is in the
# EMPTY state.  Processes the Counter Count file, checking for existence,
# correct syntax, and validity.  Any Tabulator validation errors cause the
# contents of Counter Count to be rejected, that is, its votes are not
# counted.  Regardless, the Counter Count is incorporated into the Tabulator
# dataset, which is written to the <tt><b>TABULATOR_COUNT_FILE</b></tt>.

  def add(cc_file)
    xop_empty_state_no_op()
    tab = xop_instantiate()
    cc = xop_file_process(cc_file, "Counter Count")
    tab.validate_counter_count(cc)
    tab.update_tabulator_count(cc)
    if (tab.validation_errors?)
      print "Counter Count: REJECTED\n"
    else
      print "Validating Counter Count: OK\n"
    end
    xop_file_write(tab)
    xop_warn(tab)
    state(tab)
  end
  
# Arguments:
# * <i>tc_file</i>: (<i>String</i>) Tabulator Count file name (optional)
#
# Returns: N/A
#
# Implements the "check" command, which is a no-op if the Tabulator is in the
# EMPTY state.  Processes the Tabulator Count file (using
# <tt><b>TABULATOR_COUNT_FILE</b></tt> if <i>tc_file</i> is not specified),
# checking for existence, correct syntax, and validity.

  def check(tc_file = false)
    tc_file = xop_file_prepend(TABULATOR_COUNT_FILE) if tc_file == false
    tc = xop_file_process(tc_file, "Tabulator Count")
    tab = xop_new_tabulator(false, false, false, tc)
    print "Validating Tabulator Count: OK\n" unless
      (tab.validation_errors? || tab.validation_warnings?)  
    xop_warn(tab)
    state(tab)
  end

# Arguments:
# * <i>etype</i> (<i>String</i>) error message type (SYNTAX, FILE, FATAL)
# * <i>message</i> (<i>String</i>) error message
#
# Returns: N/A
#
# Prints out an Operator error message and dies.  All errors cause abrupt
# termination.

  def errop(etype, message)
    print "\n"
    case etype
    when 'SYNTAX'
      print "** OPERATOR COMMAND ERROR ** #{message}: #{ARGV.join(" ")}\n"
    when 'FILE'
      print "** OPERATOR FILE ERROR ** #{message}\n"
    when 'FATAL'
      print "** OPERATOR FATAL ERROR ** #{message}\n"
    else
      print "** OPERATOR FATAL ERROR ** Unrecognized error type: #{type}"
    end
    exit(1)
  end

# No Arguments
#
# Returns: <i>Boolean</i>
#
# Returns <i>true</i> iff the Tabulator state is EMPTY, as evidenced by the
# non-existence of the <tt><b>TABULATOR_COUNT_FILE</b></tt> .

  private
  def xop_empty_state?()
    ! xop_file_exist?(xop_file_prepend(TABULATOR_COUNT_FILE))
  end
  
# No Arguments
#
# Returns: N/A
#
# If the Tabulator state is EMPTY, print out the state and then exit (called
# by commands that are no-ops in the EMPTY state).

  def xop_empty_state_no_op()
    if (xop_empty_state?())
      print "Tabulator State: EMPTY (Waiting for Jurisdiction and Election Definitions)\n"
      exit(0)
    end
  end
  
# Arguments:
# * <i>file</i> (<i>String</i>) file name
# * <i>type</i> (<i>String</i>) file type
# * <i>fatal</i>: (<i>Boolean</i>) indicates whether errors are FATAL (optional)
#
# Returns: <i>Hash</i>
#
# Processes a Tabulator dataset (Jurisdiction Definition, Election Definition,
# Counter Count, or Tabulator Count) in a <i>file</i> and returns the
# resulting datum.  The datum undergoes a syntax check before being returned.
# Either a FILE or a FATAL error is generated if any problems occur.

  def xop_file_process(file, type, fatal = false)
    tk = {"Tabulator Count"=>"tabulator_count",
        "Counter Count"=>"counter_count",
        "Jurisdiction Definition"=>"jurisdiction_definition",
        "Election Definition"=>"election_definition"}
    errop('FATAL', "Invalid file type: #{type}") unless tk.keys.include?(type)
    key = tk[type]
    file = xop_file_prepend(file)
    datum = xop_file_read(file, type, fatal)
    etype = (fatal ? 'FATAL' : 'FILE')
    if (datum.is_a?(Hash))
      if (datum.keys.include?(key))
        schema_file = xop_file_prepend("Schemas/#{key}_schema.yml")
        schema = xop_file_read(schema_file, "Schema", true)
        csy = xop_new_check_syntax()
        syntax_errors = csy.check_syntax(schema, datum, true)
        if (syntax_errors.length == 0)
          print "Checking Syntax of #{type}: OK\n" unless fatal
          datum
        else
          errop(etype, "Syntax error in #{type}: #{file}")
        end
      else
        errop(etype,"Hash missing key #{key} for #{type}: #{file}")
      end
    else
      errop(etype,"Contents of #{type} not a Hash: #{file}")
    end
  end
  
# Arguments:
# * <i>file</i>: (<i>String</i>) file name
#
# Returns: <i>Boolean</i>
#
# Returns the result of calling File.exist? on the named <i>file</i>.
# Generates a FATAL error if any problems occur.

  def xop_file_exist?(file)
    File.exist?(file)
  rescue
    errop('FATAL',"File.exist? failed for file: #{file}")
  end

# Arguments:
# * <i>tc_file</i>: (<i>String</i>) Tabulator data file name
#
# Returns: N/A
#
# Backs up the Tabulator data in <tt><b>TABULATOR_COUNT_FILE</b></tt> to
# <tt><b>TABULATOR_DATA_FILE</b></tt>, by moving (renaming) the first file to
# the second.  Generates a FATAL error if any problems occur.

  def xop_file_backup(tc_file)
    backup_file = xop_file_prepend(TABULATOR_BACKUP_FILE)
    print "Moving Tabulator Data in #{tc_file} to #{backup_file}\n"
    FileUtils.mv(tc_file, backup_file)
  rescue
    errop('FATAL',"FileUtils.mv failed moving #{tc_file} to #{backup_file}")
  end

# Arguments:
# * <i>file</i>: (<i>String</i>) file name
#
# Returns: <i>String</i>
#
# Temporary means of running operator.rb from the directory above which it
# normally resides, by checking the current directory and optionally
# prepending "Tabulator/" to file names if the directory contains a Tabulator
# subdirectory. Generates a FATAL error if any problems occur. FIX THIS...JVC

  def xop_file_prepend(file)
    ((File.directory?('Tabulator') && (! (file =~ /^Tabulator/))) ?
     "Tabulator/#{file}" : file)
  rescue
    errop('FATAL', "File.directory? failed for directory: Tabulator")
  end

# Arguments:
# * <i>file</i>:  (<i>String</i>) file name
# * <i>type</i>:  (<i>String</i>) file type
# * <i>fatal</i>: (<i>Boolean</i>) indicates if errors are FATAL (optional)
#
# Returns: <i>Hash</i>
#
# Reads a Tabulator dataset (Jurisdiction Definition, Election Definition,
# Counter Count, or Tabulator Count) from an existing <i>file</i> and returns
# the resulting YAML data.  Traces progress unless <i>fatal</i> is <i>true</i>.
# Generates either a FILE or FATAL (depending on <i>fatal</i> arg) error if a
# problem occurs while opening or reading from the file.

  def xop_file_read(file, type, fatal = false)
    etype = (fatal ? 'FATAL' : 'FILE')
    if (xop_file_exist?(file))
      print "Reading #{type}: #{file}\n" unless fatal
      infile = xop_file_open_read(file)
      YAML::load(infile)
    else
      errop(etype, "Non-existent file: #{file}")
    end
  rescue
    errop(etype, "YAML::load failed for file: #{file}")
  end

# Arguments:
# * <i>file</i>: (<i>String</i>) file name
#
# Returns: N/A
#
# Opens the <i>file</i> for reading.  Generates a FILE error if a problem
# occurs while opening the file.

  def xop_file_open_read(file)
    File.open(file, "r")
  rescue
    errop('FILE',"Cannot open file for reading: #{file}")
  end

# Arguments:
# * <i>file</i>: (<i>String</i>) file name
#
# Returns: N/A
#
# Opens the <i>file</i> for writing.  Generates a FILE error if a problem
# occurs while opening the file.

  def xop_file_open_write(file)
    File.open(file, "w")
  rescue
    errop('FILE',"Cannot open file for writing: #{file}")
  end

# Arguments:
# * <i>tab</i>:   (<i>Class Object</i>) Tabulator object
# * <i>trace</i>: (<i>Boolean</i>) whether to trace the write (optional)
#
# Returns: <i>Hash</i>
#
# Writes the current Tabulator data to <tt><b>TABULATOR_COUNT_FILE</b></tt>.
# Traces progress when <i>trace</i> is <i>true</i>.  Generates a FATAL error
# if problems occur while dumping the YAML data to the file, a serious error
# condition because there is no reason for the data dump to fail after the
# file was successfully opened for write access.

  def xop_file_write(tab, trace = false)
    tc_file = xop_file_prepend(TABULATOR_COUNT_FILE)
    print "Writing Tabulator Data: #{tc_file}\n" unless trace == false
    outfile = xop_file_open_write(tc_file)
    YAML::dump(tab.tabulator_count, outfile)
  rescue
    errop('FATAL',"YAML::dump failed for file: #{tc_file}")
  end

# No Arguments
#
# Returns: Tabulator Object
#
# Use the contents of the <tt><b>TABULATOR_COUNT_FILE</b></tt> to instantiate
# a new Tabulator object, which is returned.  Any problem results in a FATAL
# error, because the Tabulator would then be in an inconsistent state.

  def xop_instantiate()
    tc = xop_file_process(TABULATOR_COUNT_FILE, 'Tabulator Count', true)
    tab = xop_new_tabulator(false, false, false, tc)
    if (tab.validation_errors? || tab.validation_warnings?)
      xop_warn(tab)
      errop('FATAL',"Errors Validating Tabulator: #{tc_file}")
    end
    tab
  end
  
# Arguments:
# * <i>tab</i> (<i>Class Object</i>) Tabulator object
#
# Returns: N/A
#
# Prints out any error and/or warning messages held by the Tabulator.

  def xop_warn(tab)
    tab.validation_errors.each { |message| print "** ERROR ** #{message}\n" }
    tab.validation_warnings.each { |message| print "** WARNING ** #{message}\n" }
  end

# Arguments:
# * <i>jd</i> (<i>Hash</i>) Jurisdiction Definition
# * <i>ed</i> (<i>Hash</i>) Election Definition
# * <i>file</i> (<i>String</i>) Tabulator data file name
# * <i>tc</i> (<i>Hash</i>) Tabulator Count
#
# Returns: new Tabulator Object
#
# Returns the result of calling Tabulator.new, generating a FATAL error if any
# problems occur.

  def xop_new_tabulator(jd, ed, file, tc)
    Tabulator.new(jd, ed, file, tc)
  rescue
    errop('FATAL', "Tabulator.new failed")
  end

# No Arguments
#
# Returns: new CheckSyntaxYaml Object
#
# Returns the result of calling CheckSyntaxYaml.new, generating a FATAL error
# if any problems occur.

  def xop_new_check_syntax()
    CheckSyntaxYaml.new()
  rescue
    errop('FATAL', "CheckSyntaxYaml.new failed")
  end

end

# Command-line interface for the Tabulator Operator.
#
# For help type: ruby operator.rb
#            or: ruby operator.rb help

begin
  test = false
  if (ARGV.length > 1 && ARGV[0] == 'test')
    test = true
    ARGV.shift
  end
  operator = Operator.new
  if (ARGV.length == 0)
    operator.help()
  else
    prefix = "Command \"#{ARGV[0]}\" "
    case ARGV[0]
    when 'help'
      ((ARGV.length == 1) ?
       operator.help(true) :
       operator.errop('SYNTAX', prefix + 'has no arguments'))
    when 'reset'
      ((ARGV.length == 1) ?
       operator.reset() :
       operator.errop('SYNTAX', prefix + 'has no arguments'))
    when 'total'
      ((ARGV.length == 1) ?
       operator.total() :
       operator.errop('SYNTAX', prefix + 'has no arguments'))
    when 'data'
      ((ARGV.length == 1) ?
       operator.data() :
       operator.errop('SYNTAX', prefix + 'has no arguments'))
    when 'state'
      ((ARGV.length == 1) ?
       operator.state() :
       operator.errop('SYNTAX', prefix + 'has no arguments'))
    when 'load'
      ((ARGV.length == 1) ?
        operator.errop('SYNTAX', prefix + 'requires 2 arguments (file names)') :
       ((ARGV.length == 2) ?
        operator.errop('SYNTAX', prefix + 'needs 1 more argument (file name)') :
        ((ARGV.length == 3) ?
         operator.load(ARGV[1], ARGV[2], test) :
         operator.errop('SYNTAX', prefix + 'has only 2 arguments (file names)'))))
    when 'add'
      ((ARGV.length == 1) ?
       operator.errop('SYNTAX', prefix + 'requires 1 argument (file name)') :
       ((ARGV.length == 2) ?
        operator.add(ARGV[1]) :
        operator.errop('SYNTAX',prefix + 'has only 1 argument (file name)')))
    when 'check'
      ((ARGV.length == 1) ?
       operator.check() :
       ((ARGV.length == 2) ?
        operator.check(ARGV[1]) :
        operator.errop('SYNTAX', prefix + 'has at most 1 argument')))
    else
      operator.errop('SYNTAX', "Command \"#{ARGV[0]}\" not recognized")
    end
  end
end
