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

  TABULATOR_COUNT_FILE =       "TABULATOR_COUNT.yml"
  TABULATOR_BACKUP_FILE =      "TABULATOR_BACKUP.yml"
  TABULATOR_SPREADSHEET_FILE = "TABULATOR_SPREADSHEET.csv"

# Arguments:
# * <i>detail</i> (<i>Boolean</i>) whether to print detailed help information (optional)
#
# Returns: N/A
#
# Implements the "help" command.  Prints simple or detailed help information
# about all the Operator commands.

  def help(detail = false)
    print "\n"
    if (detail)
      print "Note: [DEBUG] indicates a temporary/prototype command option.

"
    end
    print "Commands:

  ruby operator.rb       # basic command help information
  ruby operator.rb help  # detailed command help information
  ruby operator.rb reset # reset Tabulator to EMPTY state
  ruby operator.rb data  # print Tabulator data
  ruby operator.rb state # print Tabulator state, one of: 
                              EMPTY, INITIAL, ACCUMULATING, or DONE  
  ruby operator.rb total # print Tabulator state, show missing counts, and
                              print spreadsheet with current voting results

  ruby operator.rb load <Jurisdiction_Def_File> <Election_Def_File>
"
    if (detail)
      print "
     # The two files must contain, respectively, a Jurisdiction Definition
     # and an Election Definition.  Each is checked for proper syntax and
     # then validated, after which a zero-initialized Tabulator Count is
     # constructed and saved to file.  This command moves the state of the
     # Tabulator from EMPTY to INITIAL.
"
    else
      print "
     # Process two Jurisdiction and Election Definition files to initialize
     # the Tabulator, moving its state from EMPTY to INITIAL.
"
    end
    print "
  ruby operator.rb add <Counter_Count_File>
"
    if (detail)
      print "
     # The file contains a Counter Count, rejected if the state of the
     # Tabulator is EMPTY.  First the Tabulator is re-instantiated using the
     # current Tabulator data file.  Then the Counter Count is checked for
     # proper syntax, validated, and incorporated into the Tabulator dataset,
     # which is saved to file.  This command allows the Tabulator to
     # accumulate votes, and enter the ACCUMULATING state. When the last
     # expected count is accumulated, the Tabulator enters the DONE state.
"
    else
      print "
     # Process a Counter Count file to accumulate votes.  The Tabulator state
     # becomes ACCUMULATING, unless this is the last expected count, in which
     # case the Tabulator state is DONE.
"
    end
    if (detail)
      print "
  ruby operator.rb check [<Tabulator_Count_File>]

     # [DEBUG] The file contains a Tabulator Count (the default Tabulator data
     # file used if the file is left unspecified).  It is checked for proper
     # syntax and validated.  This command is informational only and may be
     # used to check the consistency of the current Tabulator data file.
"
    end
    print "
Tabulator data file: #{TABULATOR_COUNT_FILE}

"
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
    unless (xop_empty?())
      print "Moving Tabulator Data in #{TABULATOR_COUNT_FILE} to #{TABULATOR_BACKUP_FILE}\n"
      xop_file_backup()
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
      print "\nWriting Tabulator Spreadsheet: #{TABULATOR_SPREADSHEET_FILE}\n"
      lines = xop_file_write_spreadsheet(tab)
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
# initial Tabulator dataset.  In testing mode, <i>proceed</i> is <i>true</i>,
# and they are used without question.  Otherwise, the operator is shown a data
# summary, asked for confirmation, and they are used only if approved,
# rejected otherwise.

  def load(jd_file, ed_file, proceed = false)
    errop("Command \"load\" ignored, Tabulator state: not EMPTY") unless
      xop_empty?()
    print "Reading Jurisdiction Definition: #{jd_file}\n"
    jd = xop_file_process(jd_file, "Jurisdiction Definition",
                          "jurisdiction_definition")
    print "Reading Election Definition: #{ed_file}\n"
    ed = xop_file_process(ed_file, "Election Definition", "election_definition")
    tab = xop_new_tabulator(jd, ed, TABULATOR_COUNT_FILE, false)
    if (tab.validation_errors?)
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
    cc = xop_file_process(cc_file, "Counter Count", "counter_count")
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
    tc_file = TABULATOR_COUNT_FILE if tc_file == false
    print "Reading Tabulator Count: #{tc_file}\n"
    tc = xop_file_process(tc_file, "Tabulator Count", "tabulator_count")
    tab = xop_new_tabulator(false, false, false, tc)
    print "Validating Tabulator Count: OK\n" unless
      (tab.validation_errors? || tab.validation_warnings?)  
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
    print "\n** OPERATOR ERROR ** #{message}\n"
    exit(1)
  end

# Arguments:
# * <i>tab</i> (<i>Class Object</i>) Tabulator object
#
# Returns: Tabulator Object
#
# Prints out any error and/or warning messages held by the Tabulator object,
# and then returns it.

  def warn(tab)
    tab.validation_errors.each {|message| print "** ERROR ** #{message}\n"}
    tab.validation_warnings.each {|message| print "** WARNING ** #{message}\n"}
    tab
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
# * <i>key</i> (<i>String</i>) Hash key expected to appear in file
# * <i>fatal</i>: (<i>Boolean</i>) indicates when errors are Fatal (optional)
#
# Returns: <i>Hash</i>
#
# Processes a Tabulator input dataset (Jurisdiction Definition, Election
# Definition, Counter Count, or Tabulator Count) stored in <i>file</i> and
# returns the resulting datum.  The datum undergoes a syntax check against a
# built-in schema before being returned.  Generates a File or Fatal error
# (depending on <i>fatal</i>, which is <i>true</i> only when processing the
# <tt><b>TABULATOR_COUNT_FILE</b></tt>) if any problems occur.

  def xop_file_process(file, type, key, fatal = false)
    etype = (fatal ? "Fatal" : "File")
    schema_file = xop_file_prepend("Schemas/#{key}_schema.yml")
    schema = xop_file_read(schema_file, "Schema", true)
    file = xop_file_prepend(file)
    datum = xop_file_read(file, type, fatal)
    if (!datum.is_a?(Hash))
      errop("#{etype} error, contents of #{type} not a Hash: #{file}")
    elsif (!datum.keys.include?(key))
      errop("#{etype} error, Hash missing Key #{key} for #{type}: #{file}")
    elsif (xop_check_syntax(schema, datum))
      datum
    else
      errop("#{etype} syntax error in #{type}: #{file}")
    end
  rescue
    errop("Fatal failure processing file: #{file}")
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

# No Arguments
#
# Returns: N/A
#
# Backs up the Tabulator data in <tt><b>TABULATOR_COUNT_FILE</b></tt> to
# <tt><b>TABULATOR_BACKUP_FILE</b></tt>, by moving (renaming) the first file to
# the second.  Generates a Fatal error if any problems occur during the move.

  def xop_file_backup()
    FileUtils.mv(xop_file_prepend(TABULATOR_COUNT_FILE),
                 xop_file_prepend(TABULATOR_BACKUP_FILE))
  rescue
    errop("Fatal failure of FileUtils.mv to backup #{TABULATOR_COUNT_FILE}")
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
    ((File.directory?("Tabulator")) ? "Tabulator/#{file}" : file)
  rescue
    errop("Fatal failure of File.directory? for directory: Tabulator/")
  end

# Arguments:
# * <i>file</i>:  (<i>String</i>) file name
# * <i>type</i>:  (<i>String</i>) file type
# * <i>fatal</i>: (<i>Boolean</i>) indicates when errors are Fatal (optional)
#
# Returns: <i>Hash</i>
#
# Reads a Tabulator dataset (Jurisdiction Definition, Election Definition,
# Counter Count, or Tabulator Count) from an existing <i>file</i> and returns
# the resulting YAML dataset.  Generates a File or Fatal error (depending on
# <i>fatal</i>, which is <i>true</i> only when reading the
# <tt><b>TABULATOR_COUNT_FILE</b></tt> or a built-in Schema file) if
# a problem occurs while reading from the file.

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
# Returns: <i>File Handle</i>
#
# Opens the <i>file</i> for reading and returns the resulting file handle.
# Generates a File or Fatal error (depending on <i>fatal</i>, which is
# <i>true</i> only when opening the <tt><b>TABULATOR_COUNT_FILE</b></tt> or a
# built-in Schema file) if a problem occurs while opening the file.

  def xop_file_open_read(file, fatal = false)
    File.open(file, "r")
  rescue
    (fatal ?
     errop("Fatal failure of File.open for reading: #{file}") :
     errop("File open error while trying to read: #{file}"))
  end

# Arguments:
# * <i>file</i>: (<i>String</i>) file name
#
# Returns: <i>File Handle</i>
#
# Opens the <i>file</i> for writing and returns the resulting file handle.
# Generates a Fatal error if a problem occurs while opening the file.

  def xop_file_open_write(file)
    File.open(file, "w")
  rescue
    errop("Fatal failure of File.open for writing: #{file}")
  end

# Arguments:
# * <i>tab</i>: (<i>Class Object</i>) Tabulator object
#
# Returns: <i>Array</i> of <i>String</i>
#
# Calls the Tabulator to produce the lines of textual data for a CSV
# spreadsheet representing the current set of voting results, which it writes
# to <tt><b>TABULATOR_SPREADSHEET_FILE</b></tt>, and then returns.  Generates
# a Fatal error if problems occur during the write.

  def xop_file_write_spreadsheet(tab)
    lines = tab.tabulator_spreadsheet()
    outfile = xop_file_open_write(xop_file_prepend(TABULATOR_SPREADSHEET_FILE))
    outfile.puts lines
    outfile.close()
    lines
  rescue
    errop("Fatal failure writing to spreadsheet file: #{file}")
  end

# Arguments:
# * <i>tab</i>: (<i>Class Object</i>) Tabulator object
#
# Returns: N/A
#
# Writes the current Tabulator data to <tt><b>TABULATOR_COUNT_FILE</b></tt>.
# Generates a Fatal error if problems occur while writing to the file.

  def xop_file_write_tabulator(tab)
    outfile = xop_file_open_write(xop_file_prepend(TABULATOR_COUNT_FILE))
    YAML::dump(tab.tabulator_count, outfile)
  rescue
    errop("Fatal failure of YAML::dump for file: #{TABULATOR_COUNT_FILE}")
  end

# No Arguments
#
# Returns: Tabulator Object
#
# Use the contents of the <tt><b>TABULATOR_COUNT_FILE</b></tt> to instantiate
# a new Tabulator object, which is returned.  Generates a Fatal error if there
# are any Tabulator validation errors or warnings, because this implies that
# Tabulator is in an inconsistent state.

  def xop_instantiate()
    file = TABULATOR_COUNT_FILE
    tc = xop_file_process(file, "Tabulator Count", "tabulator_count", true)
    tab = xop_new_tabulator(false, false, false, tc)
    errop("Fatal failure during Tabulator validation: #{file}") if
      (tab.validation_errors? || tab.validation_warnings?)
    tab
  rescue
    errop("Fatal failure during Tabulator instantiation")
  end
  
# Arguments:
# * <i>jd</i> (<i>Hash</i>) Jurisdiction Definition
# * <i>ed</i> (<i>Hash</i>) Election Definition
# * <i>file</i> (<i>String</i>) Tabulator data file name
# * <i>tc</i> (<i>Hash</i>) Tabulator Count
#
# Returns: new Tabulator Object
#
# Returns the result of calling Tabulator.new.  Generates a Fatal error if any
# problems occur.

  def xop_new_tabulator(jd, ed, file, tc)
    warn(Tabulator.new(jd, ed, file, tc))
  rescue
    errop("Fatal failure of Tabulator.new(...)")
  end

# Arguments:
# * <i>schema</i> (<i>Hash</i>) built-in Schema for syntax checking
# * <i>datum</i> (<i>Hash</i>) Tabulator input dataset to be syntax-checked
#
# Returns: <i>Boolean</i>
#
# Returns <i>true</i> iff there are no errors resulting from syntax-checking
# the <i>datum</i> against the <i>schema</i>.  Generates a Fatal error if any
# problems occur.

  def xop_check_syntax(schema, datum)
    (CheckSyntaxYaml.new.check_syntax(schema, datum, true).length == 0)
  rescue
    errop("Fatal failure of CheckSyntaxYaml.new.check_syntax(...)")
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
rescue
  print "!!!!!!!!!!!!
!!!!!!!!!!!!
Jeff, remove the rescue clause from the Operator begin...end!
At least while you are still debugging!\n"
  exit(1)
end
