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

$LOAD_PATH << "./Tabulator"

require "yaml"
require "fileutils"
require "check_syntax_yaml"
require "tabulator"

class Operator

  TABULATOR_COUNT_FILE =  "TABULATOR_COUNT.yml"
                        
  TABULATOR_BACKUP_FILE = "TABULATOR_BACKUP.yml"

  TABULATOR_SPREADSHEET_FILE = "TABULATOR_SPREADSHEET.csv"

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
      backup_file = xop_file_prepend(TABULATOR_BACKUP_FILE)
      print "Moving Tabulator Data in #{tc_file} to #{backup_file}\n"
      xop_file_backup(tc_file, backup_file)
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
    elsif (xop_empty?())
      errop("Command \"data\" ignored, Tabulator state: EMPTY")
    else
      tab = xop_instantiate()
      tab.tabulator_data(true)
    end
  end

# Arguments:
# * <i>tab</i> (<i>Class Object</i>) Tabulator object (optional)
# * <i>detail</i> (<i>Boolean</i>) whether to print details about the state (optional)
#
# Returns: N/A
#
# Implements the "state" command.  Prints the Tabulator state either using the
# optional Tabulator object (<i>tab</i>) provided as input or by
# re-instantiating the Tabulator from its persistent data file
# <tt><b>TABULATOR_COUNT_FILE</b></tt>.  If indicated, print detailed
# concerning the missing counts.

  def state(tab = false, detail = false)
    errop("Command \"state\" ignored, Tabulator state: EMPTY") if xop_empty?()
    tab = xop_instantiate() unless tab
    mystate = tab.tabulator_state
    state = mystate[0].split(/ /)[0]
    print "Tabulator State: #{mystate[0]}\n"
    if (detail && (state == "ACCUMULATING"))
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
# detailed state information, then writes out a Tabulator spreadsheet
# containing the current vote count. (For now, it also prints the CSV data to
# STDOUT, but this is only for testing.)

  def total()
    errop("Command \"total\" ignored, Tabulator state: EMPTY") if xop_empty?()
    tab = xop_instantiate()
    if (["ACCUMULATING", "DONE"].include?(state(tab, true)))
      file = xop_file_prepend(TABULATOR_SPREADSHEET_FILE)
      print "\nWriting Tabulator Spreadsheet: #{file}\n"
      lines = xop_file_write_spreadsheet(tab, file)
      print "\nSpreadsheet Data (CSV Format):\n\n"
      print lines
    end
  end
  
# Arguments:
# * <i>jd_file</i> (<i>String</i>) Jurisdiction Definition (JD) File
# * <i>ed_file</i> (<i>String</i>) Election Definition (JD) File
# * <i>proceed</i> (<i>Boolean</i>) indicates when to proceed without asking the operator (optional, for testing)
#
# Returns: N/A
#
# Implements the "load" command, which is a no-op unless the Tabulator is in
# the EMPTY state.  Processes the JD and ED files, checking them for
# existence, correct syntax, and validity.  Any Tabulator validation errors
# cause them to be rejected, otherwise they may be used to create a new
# initial Tabulator dataset.  In testing mode (<i>proceed</i> is <i>true</i>),
# they are used without question.  Otherwise, the operator is shown a data
# summary, asked for confirmation, and they are used only if approved.

  def load(jd_file, ed_file, proceed = false)
    errop("Command \"load\" ignored, Tabulator state: not EMPTY") unless
      xop_empty?()
    print "Reading Jurisdiction Definition: #{jd_file}\n"
    jd = xop_file_process(jd_file, "Jurisdiction Definition")
    print "Reading Election Definition: #{ed_file}\n"
    ed = xop_file_process(ed_file, "Election Definition")
    tc_file = xop_file_prepend(TABULATOR_COUNT_FILE)
    tab = xop_new_tabulator(jd, ed, tc_file, false)
    if (tab.validation_errors?)
      warn(tab)
      print "Jurisdiction and Election Definitions: REJECTED\n"
    elsif (proceed)
      print "Jurisdiction and Election Definitions: ACCEPTED\n"
      xop_file_write_tabulator(tab)
      state(tab)
    else
      print "\n"
      data(tab)
      warn(tab)
      print "** ATTENTION ** ATTENTION **
Carefully examine the data above, then confirm approval to continue [y/n]: "
      answer = STDIN.gets.chomp
      if (answer =~ /^[Yy]/)
        print "\nJurisdiction and Election Definitions: ACCEPTED\n\n"
        xop_file_write_tabulator(tab)
        state(tab)
      else
        print "Jurisdiction and Election Definitions: REJECTED\n"
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
    errop("Command \"add\" ignored, Tabulator State: EMPTY\n") if xop_empty?()
    tab = xop_instantiate()
    print "Reading Counter Count: #{cc_file}\n"
    cc = xop_file_process(cc_file, "Counter Count")
    tab.validate_counter_count(cc)
    tab.update_tabulator_count(cc)
    if (tab.validation_errors?)
      print "Counter Count: REJECTED\n"
    else
      print "Counter Count: ACCUMULATED\n"
    end
    xop_file_write_tabulator(tab)
    warn(tab)
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
    print "Reading Tabulator Count: #{tc_file}\n"
    tc = xop_file_process(tc_file, "Tabulator Count")
    tab = xop_new_tabulator(false, false, false, tc)
    print "Validating Tabulator Count: OK\n" unless
      (tab.validation_errors? || tab.validation_warnings?)  
    warn(tab)
    state(tab)
  end

# Arguments:
# * <i>message</i> (<i>String</i>) error message
#
# Returns: N/A
#
# Prints out an Operator error message and dies.  All errors cause immediate
# termination.

  def errop(message)
    print "\n"
    print "** OPERATOR ERROR ** #{message}\n"
    exit(1)
  end

# Arguments:
# * <i>tab</i> (<i>Class Object</i>) Tabulator object
#
# Returns: N/A
#
# Prints out any error and/or warning messages held by the Tabulator.

  def warn(tab)
    tab.validation_errors.each { |message| print "** ERROR ** #{message}\n" }
    tab.validation_warnings.each { |message| print "** WARNING ** #{message}\n" }
  end

# No Arguments
#
# Returns: <i>Boolean</i>
#
# Returns <i>true</i> iff the Tabulator state is EMPTY, as evidenced by the
# non-existence of the <tt><b>TABULATOR_COUNT_FILE</b></tt> .

  private
  def xop_empty?()
    ! xop_file_exist?(xop_file_prepend(TABULATOR_COUNT_FILE))
  end
  
# Arguments:
# * <i>file</i> (<i>String</i>) file name
# * <i>type</i> (<i>String</i>) file type
# * <i>fatal</i>: (<i>Boolean</i>) indicates whether errors are Fatal (optional)
#
# Returns: <i>Hash</i>
#
# Processes a Tabulator dataset (Jurisdiction Definition, Election Definition,
# Counter Count, or Tabulator Count) in a <i>file</i> and returns the
# resulting datum.  The datum undergoes a syntax check before being returned.
# Either a File or a Fatal error is generated if any problems occur.

  def xop_file_process(file, type, fatal = false)
    tk = {"Tabulator Count"=>"tabulator_count",
      "Counter Count"=>"counter_count",
      "Jurisdiction Definition"=>"jurisdiction_definition",
      "Election Definition"=>"election_definition"}
    key = tk[type]
    file = xop_file_prepend(file)
    datum = xop_file_read(file, type, fatal = false)
    if (datum.is_a?(Hash))
      if (datum.keys.include?(key))
        schema_file = xop_file_prepend("Schemas/#{key}_schema.yml")
        schema = xop_file_read(schema_file, "Schema", true)
        csy = xop_new_check_syntax()
        syntax_errors = csy.check_syntax(schema, datum, true)
        if (syntax_errors.length == 0)
          datum
        else
          (fatal ?
           errop("Fatal syntax error in #{type}: #{file}") :
           errop("File syntax error in #{type}: #{file}"))
        end
      else
        (fatal ?
         errop("Fatal error, hash missing key #{key} for #{type}: #{file}") :
         errop("File error, hash missing key #{key} for #{type}: #{file}"))
      end
    else
      (fatal ?
       errop("Fatal error, contents of #{type} not a Hash: #{file}") :
       errop("File error, contents of #{type} not a Hash: #{file}"))
    end
  end
  
# Arguments:
# * <i>file</i>: (<i>String</i>) file name
#
# Returns: <i>Boolean</i>
#
# Returns the result of calling File.exist? on the named <i>file</i>.
# Generates a Fatal error if any problems occur.

  def xop_file_exist?(file)
    File.exist?(file)
  rescue
    errop("Fatal failure of File.exist? for file: #{file}")
  end

# Arguments:
# * <i>tc_file</i>: (<i>String</i>) Tabulator data file name
# * <i>backup_file</i>: (<i>String</i>) Tabulator data backup file name
#
# Returns: N/A
#
# Backs up the Tabulator data in <tt><b>TABULATOR_COUNT_FILE</b></tt> to
# <tt><b>TABULATOR_DATA_FILE</b></tt>, by moving (renaming) the first file to
# the second.  Generates a Fatal error if any problems occur.

  def xop_file_backup(tc_file, backup_file)
    FileUtils.mv(tc_file, backup_file)
  rescue
    errop("Fatal failure of FileUtils.mv moving #{tc_file} to #{backup_file}")
  end

# Arguments:
# * <i>file</i>: (<i>String</i>) file name
#
# Returns: <i>String</i>
#
# Temporary means of running operator.rb from the directory above which it
# normally resides, by checking the current directory and optionally
# prepending "Tabulator/" to file names if the directory contains a Tabulator
# subdirectory. Generates a Fatal error if any problems occur. FIX THIS...JVC

  def xop_file_prepend(file)
    ((File.directory?("Tabulator") && (! (file =~ /^Tabulator/))) ?
     "Tabulator/#{file}" : file)
  rescue
    errop("Fatal failure of File.directory? for directory: Tabulator")
  end

# Arguments:
# * <i>file</i>:  (<i>String</i>) file name
# * <i>type</i>:  (<i>String</i>) file type
# * <i>fatal</i>: (<i>Boolean</i>) indicates if errors are Fatal (optional)
#
# Returns: <i>Hash</i>
#
# Reads a Tabulator dataset (Jurisdiction Definition, Election Definition,
# Counter Count, or Tabulator Count) from an existing <i>file</i> and returns
# the resulting YAML data.  Traces progress unless <i>fatal</i> is <i>true</i>.
# Generates either a File or Fatal (depending on <i>fatal</i> arg) error if a
# problem occurs while opening or reading from the file.

  def xop_file_read(file, type, fatal = false)
    if (xop_file_exist?(file))
      infile = xop_file_open_read(file, fatal)
      YAML::load(infile)
    else
      (fatal ?
       errop("Fatal failure, non-existent file: #{file}") :
       errop("File non-existent: #{file}"))
    end
  rescue
    (fatal ?
     errop("Fatal failure of YAML::load for file: #{file}") :
     errop("File read error in YAML::load for file: #{file}"))
  end

# Arguments:
# * <i>file</i>: (<i>String</i>) file name
# * <i>fatal</i>: (<i>Boolean</i>) indicates when errors are Fatal (optional)
#
# Returns: N/A
#
# Opens the <i>file</i> for reading.  Generates a File or Fatal error if a
# problem occurs while opening the file.

  def xop_file_open_read(file, fatal = false)
    File.open(file, "r")
  rescue
    (fatal ?
     errop("Fatal failure of File.open for reading: #{file}") :
     errop("File will not open for reading: #{file}"))
  end

# Arguments:
# * <i>file</i>: (<i>String</i>) file name
#
# Returns: N/A
#
# Opens the <i>file</i> for writing.  Generates a Fatal error if a problem
# occurs while opening the file.

  def xop_file_open_write(file)
    File.open(file, "w")
  rescue
    errop("Fatal failure of File.open for writing: #{file}")
  end

# Arguments:
# * <i>tab</i>: (<i>Class Object</i>) Tabulator object
# * <i>file</i>: (<i>String</i>) output file name for spreadsheet
#
# Returns: N/A
#
# Calls the Tabulator to produce the lines of data for a CSV spreadsheet
# representing the current set of voting results, which it writes to
# <tt><b>TABULATOR_SPREADSHEET_FILE</b></tt>.  Generates a Fatal error if
# problems occur during the write.

  def xop_file_write_spreadsheet(tab, file)
    lines = tab.tabulator_spreadsheet()
    outfile = xop_file_open_write(file)
    outfile.puts lines
    outfile.close()
    lines
  rescue
    errop("Fatal failure writing to file: #{file}")
  end

# Arguments:
# * <i>tab</i>: (<i>Class Object</i>) Tabulator object
#
# Returns: <i>Hash</i>
#
# Writes the current Tabulator data to <tt><b>TABULATOR_COUNT_FILE</b></tt>.
# Generates a Fatal error if problems occur while dumping the YAML data to the
# file, a serious error condition because there is no reason for the data dump
# to fail after the file was successfully opened for write access.

  def xop_file_write_tabulator(tab)
    tc_file = xop_file_prepend(TABULATOR_COUNT_FILE)
    outfile = xop_file_open_write(tc_file)
    YAML::dump(tab.tabulator_count, outfile)
  rescue
    errop("Fatal failure of YAML::dump for file: #{tc_file}")
  end

# No Arguments
#
# Returns: Tabulator Object
#
# Use the contents of the <tt><b>TABULATOR_COUNT_FILE</b></tt> to instantiate
# a new Tabulator object, which is returned.  Any problem results in a Fatal
# error, because the Tabulator would then be in an inconsistent state.

  def xop_instantiate()
    tc = xop_file_process(TABULATOR_COUNT_FILE, "Tabulator Count", true)
    tab = xop_new_tabulator(false, false, false, tc)
    if (tab.validation_errors? || tab.validation_warnings?)
      warn(tab)
      errop("Fatal failure during Tabulator validation: #{tc_file}")
    end
    tab
  end
  
# Arguments:
# * <i>jd</i> (<i>Hash</i>) Jurisdiction Definition
# * <i>ed</i> (<i>Hash</i>) Election Definition
# * <i>file</i> (<i>String</i>) Tabulator data file name
# * <i>tc</i> (<i>Hash</i>) Tabulator Count
#
# Returns: new Tabulator Object
#
# Returns the result of calling Tabulator.new, generating a Fatal error if any
# problems occur.

  def xop_new_tabulator(jd, ed, file, tc)
    Tabulator.new(jd, ed, file, tc)
  rescue
    errop("Fatal failure of Tabulator.new")
  end

# No Arguments
#
# Returns: new CheckSyntaxYaml Object
#
# Returns the result of calling CheckSyntaxYaml.new, generating a Fatal error
# if any problems occur.

  def xop_new_check_syntax()
    CheckSyntaxYaml.new()
  rescue
    errop("Fatal failure of CheckSyntaxYaml.new")
  end

end

# Command-line interface for the Tabulator Operator.
#
# For help type: ruby operator.rb
#            or: ruby operator.rb help

begin
  operator = Operator.new
  if (ARGV.length == 0)
    operator.help()
  else
    cmd = "\"#{ARGV[0]}\""
    case ARGV[0]
    when "help"
      ((ARGV.length == 1) ?
       operator.help(true) :
       operator.errop("Command #{cmd} has no arguments"))
    when "reset"
      ((ARGV.length == 1) ?
       operator.reset() :
       operator.errop("Command #{cmd} has no arguments"))
    when "total"
      ((ARGV.length == 1) ?
       operator.total() :
       operator.errop("Command #{cmd} has no arguments"))
    when "data"
      ((ARGV.length == 1) ?
       operator.data() :
       operator.errop("Command #{cmd} has no arguments"))
    when "state"
      ((ARGV.length == 1) ?
       operator.state() :
       operator.errop("Command #{cmd} has no arguments"))
    when "load"
      ((ARGV.length == 1) ?
        operator.errop("Command #{cmd} requires 2 arguments (file names)") :
       ((ARGV.length == 2) ?
        operator.errop("Command #{cmd} needs 1 more argument (file name)") :
        ((ARGV.length == 3) ?
         operator.load(ARGV[1], ARGV[2]) :
         (((ARGV.length == 4) && (ARGV[3] =~ /^OK$/)) ?
          operator.load(ARGV[1], ARGV[2], true) :
          operator.errop("Command #{cmd} has only 2 arguments (file names)")))))
    when "add"
      ((ARGV.length == 1) ?
       operator.errop("Command #{cmd} requires 1 argument (file name)") :
       ((ARGV.length == 2) ?
        operator.add(ARGV[1]) :
        operator.errop("Command #{cmd} has only 1 argument (file name)")))
    when "check"
      ((ARGV.length == 1) ?
       operator.check() :
       ((ARGV.length == 2) ?
        operator.check(ARGV[1]) :
        operator.errop("Command #{cmd} has at most 1 argument (file name)")))
    else
      operator.errop("Command #{cmd} not recognized")
    end
  end
end
