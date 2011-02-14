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

$LOAD_PATH << "./Tabulator" # Temporary, for testing

require "yaml"
require "fileutils"
require "check_syntax_yaml"
require "tabulator"

# The OperatorError class is used by the Tabulator Opertor to perform
# error-handling; it holds a single value, the error message string.

class OperatorError < Exception
  def initialize(message)
    @message = message
  end
  def error_message
    return @message
  end
end

# The Operator class contains the Tabulator Operator.  Methods beginning with
# "op_" are public, and there is only one such, op_command, which implements
# the command-line interface to the Operator.  Methods beginning with "opc_"
# implement Operator commands.  Methods beginning with "opx_" are private and
# this is where all of the system calls are made.  All such methods are
# protected from exceptions by rescue clauses that cause either a File error,
# in the case the exception was raised while processing an Operator-supplied
# file, or a Fatal error, in the case that the operation being performed was
# internal to the Tabulator and/or Operator and should never encounter
# problems.  There is one other type of error, a Command error, which occurs
# when an Operator command is syntactically invalid.
#
# The Operator handles errors by raising the OperatorError exception, passing
# it the error message.  This exception is caught only by op_command, which
# prints out the error message and terminates.

class Operator

  TABULATOR_COUNT_FILE =       "TABULATOR_COUNT.yml"
  TABULATOR_BACKUP_FILE =      "TABULATOR_BACKUP.yml"
  TABULATOR_SPREADSHEET_FILE = "TABULATOR_SPREADSHEET.csv"

# Arguments:
# * <i>args</i> (<i>Array</i>) command-line arguments
#
# Returns: <i>String</i>
#
# Rescues: OperatorError
#
# Implements the command-line interface for the Tabulator Operator.

  def op_command(args)
    if (args.length == 0)
      opc_help()
    else
      cmd = "\"#{args[0]}\""
      opx_err("Command #{cmd} has no arguments") if (args.length > 1) &&
        ["help", "reset", "data", "state", "total"].include?(args[0])
      case args[0]
      when "help"
         opc_help(true)
      when "reset"
         opc_reset()
      when "data"
         opc_data()
      when "state"
         opc_state()
      when "total"
         opc_total()
      when "load"
        if (args.length == 3)
          opc_load(args[1], args[2])
        elsif ((args.length == 4) && (args[3] == "OK"))
          opc_load(args[1], args[2], true)
        else
          opx_err("Command #{cmd} has 2 arguments (file names)")
        end
      when "add"
        if (args.length == 2)
          opc_add(args[1])
        else
          opx_err("Command #{cmd} has 1 argument (file name)")
        end
      when "check"
        if (args.length <= 2)
          opc_check((args.length == 1) ? false : args[1])
        else
          opx_err("Command #{cmd} has 1 optional argument (file name)")
        end
      else
        opx_err("Command #{cmd} not recognized")
      end
    end
    return ""
  rescue OperatorError => opex
    message = opex.error_message
    opx_print("** TABOP ERROR ** #{message}\n")
    return message
  rescue
    opx_print("!!!!!!!  Jeff, remove this for debugging !!!!!!!\n")
    return "SHOULD NEVER HAPPEN, Unhandled Exception"
  end

# Arguments:
# * <i>detail</i> (<i>Boolean</i>) whether to print detailed help information (optional)
#
# Returns: N/A
#
# Implements the "help" command.  Prints simple or detailed help information
# concerning the Operator commands.

  private
  def opc_help(detail = false)
    opx_print("\n")
    if (detail)
      opx_print("Note: [DEBUG] indicates a temporary/prototype command option.

")
    end
    opx_print("Commands:

  ruby operator.rb       # basic command help information
  ruby operator.rb help  # detailed command help information
  ruby operator.rb reset # reset Tabulator to EMPTY state
  ruby operator.rb data  # print Tabulator data
  ruby operator.rb state # print Tabulator state, one of: 
                              EMPTY, INITIAL, ACCUMULATING, or DONE  
  ruby operator.rb total # print Tabulator state, show missing counts, and
                              print spreadsheet with current voting results

  ruby operator.rb load <Jurisdiction_Def_File> <Election_Def_File>
")
    if (detail)
      opx_print("
     # The two files must contain, respectively, a Jurisdiction Definition
     # and an Election Definition.  Each is checked for proper syntax and
     # then validated, after which a zero-initialized Tabulator Count is
     # constructed and saved to file.  This command moves the state of the
     # Tabulator from EMPTY to INITIAL.
")
    else
      opx_print("
     # Process two Jurisdiction and Election Definition files to initialize
     # the Tabulator, moving its state from EMPTY to INITIAL.
")
    end
    opx_print("
  ruby operator.rb add <Counter_Count_File>
")
    if (detail)
      opx_print("
     # The file contains a Counter Count, rejected if the state of the
     # Tabulator is EMPTY.  First the Tabulator is re-instantiated using the
     # current Tabulator data file.  Then the Counter Count is checked for
     # proper syntax, validated, and incorporated into the Tabulator dataset,
     # which is saved to file.  This command allows the Tabulator to
     # accumulate votes, and enter the ACCUMULATING state. When the last
     # expected count is accumulated, the Tabulator enters the DONE state.
")
    else
      opx_print("
     # Process a Counter Count file to accumulate votes.  The Tabulator state
     # becomes ACCUMULATING, unless this is the last expected count, in which
     # case the Tabulator state is DONE.
")
    end
    if (detail)
      opx_print("
  ruby operator.rb check [<Tabulator_Count_File>]

     # [DEBUG] The file contains a Tabulator Count (the default Tabulator
     # dataset is used if the file is left unspecified).  It is checked for
     # proper syntax and validated.  This command is informational only and
     # may be used to check the consistency of the current Tabulator dataset.
")
    end
    opx_print("
Tabulator data file: #{TABULATOR_COUNT_FILE}

")
  end

# No Arguments
#
# Returns: N/A
#
# Implements the "reset" command.  Resets the Tabulator state to
# EMPTY, by backing up the contents of (moving) the Tabulator data file from
# <tt><b>TABULATOR_COUNT_FILE</b></tt> to
# <tt><b>TABULATOR_BACKUP_FILE</b></tt>.

  def opc_reset()
    opx_file_backup() unless opx_empty?()
    opx_print("Tabulator reset to EMPTY state.\n")
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

  def opc_data(tab = false)
    if (tab != false)
      tab.tabulator_dump_data()
    elsif (opx_empty?())
      opx_err("Command \"data\" ignored, Tabulator state: EMPTY")
    else
      tab = opx_instantiate()
      tab.tabulator_dump_data(true)
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

  def opc_state(tab = false, detail = false)
    opx_err("Command \"state\" ignored, Tabulator state: EMPTY") if opx_empty?()
    tab = opx_instantiate() unless tab
    state, missing, finished, expected = tab.tabulator_state
    opx_print("Tabulator State: #{state}\n")
    state = state.split(/ /)[0]
    if (detail && (state == "ACCUMULATING"))
      if (expected == 0)
        opx_print("No Missing Counts, because no Expected Counts\n")
        return state
      end
      opx_print("Missing Counts: Counter UID, Precinct UID, Reporting Group\n")
      missing.each { |cid, rg, pid| opx_print("  #{cid}, #{pid}, #{rg}\n") }
      opx_print("Precincts Finished Reporting: ")
      if (finished.length == 0) 
        opx_print("NONE\n")
      else
        opx_print("#{finished.inspect.gsub(/[\")\[\]]/,"")}\n")
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

  def opc_total()
    opx_err("Command \"total\" ignored, Tabulator state: EMPTY") if opx_empty?()
    tab = opx_instantiate()
    if (["ACCUMULATING", "DONE"].include?(opc_state(tab, true)))
      opx_print("\nWriting Tabulator Spreadsheet: #{TABULATOR_SPREADSHEET_FILE}\n")
      lines = opx_file_write_spreadsheet(tab)
      opx_print("\nSpreadsheet Data (CSV Format):\n\n")
      opx_print(lines)
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

  def opc_load(jd_file, ed_file, proceed = false)
    opx_err("Command \"load\" ignored, Tabulator state: not EMPTY") unless
      opx_empty?()
    opx_print("Reading Jurisdiction Definition: #{jd_file}\n")
    jd = opx_file_process(jd_file, "Jurisdiction Definition",
                          "jurisdiction_definition")
    opx_print("Reading Election Definition: #{ed_file}\n")
    ed = opx_file_process(ed_file, "Election Definition", "election_definition")
    tab = opx_new_tabulator(jd, ed, TABULATOR_COUNT_FILE, false)
    if (tab.validation_errors?)
      opx_print("Jurisdiction and Election Definitions: REJECTED\n")
    elsif (proceed)
      opx_print("Jurisdiction and Election Definitions: ACCEPTED\n")
      opx_file_write_tabulator(tab)
      opc_state(tab)
    else
      opx_print("\n")
      opc_data(tab)
      opx_warn(tab)
      opx_print("** ATTENTION ** ATTENTION **

Carefully examine the data above, then confirm approval to continue [y/n]: ")
      answer = STDIN.gets.chomp
      opx_print("\n")
      if (answer =~ /^[Yy]/)
        opx_print("Jurisdiction and Election Definitions: ACCEPTED\n\n")
        opx_file_write_tabulator(tab)
        opc_state(tab)
      else
        opx_print("Jurisdiction and Election Definitions: REJECTED\n")
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
# Counter Count to be rejected, that is, its votes are not counted.
# Regardless, the Counter Count is incorporated into the Tabulator dataset,
# which is written to the <tt><b>TABULATOR_COUNT_FILE</b></tt>.

  def opc_add(cc_file)
    opx_err("Command \"add\" ignored, Tabulator State: EMPTY\n") if opx_empty?()
    tab = opx_instantiate()
    opx_print("Reading Counter Count: #{cc_file}\n")
    cc = opx_file_process(cc_file, "Counter Count", "counter_count")
    tab.validate_counter_count(cc)
    tab.update_tabulator_count(cc)
    if (tab.validation_errors?)
      opx_print("Counter Count: REJECTED\n")
    else
      opx_print("Counter Count: ACCUMULATED\n")
    end
    opx_file_write_tabulator(tab)
    opx_warn(tab)
    opc_state(tab)
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

  def opc_check(tc_file = false)
    if (tc_file == false)
      opx_err("Command \"check\" ignored, Tabulator state: EMPTY") if
        opx_empty?()
      tc_file = TABULATOR_COUNT_FILE
    end
    opx_print("Reading Tabulator Count: #{tc_file}\n")
    tc = opx_file_process(tc_file, "Tabulator Count", "tabulator_count")
    tab = opx_new_tabulator(false, false, false, tc)
    opx_print("Validating Tabulator Count: OK\n") unless
      (tab.validation_errors? || tab.validation_warnings?)  
    opc_state(tab)
  end

# Arguments:
# * <i>message</i> (<i>String</i>) error message
#
# Returns: N/A
#
# Handles Operator errors by raising the OperatorError exception.

  def opx_err(message)
    raise OperatorError.new(message)
  end

# Arguments:
# * <i>text</i> (<i>String</i>) text to print
#
# Returns: N/A
#
# Prints the <i>text</i> to STDOUT.  Generates a Fatal error if problems occur.

  def opx_print(text)
    print text
  rescue
    opx_error("Fatal error while printing to STDOUT: #{text}")
  end

# Arguments:
# * <i>tab</i> (<i>Class Object</i>) Tabulator object
#
# Returns: Tabulator Object
#
# Prints out any error and/or warning messages held by the Tabulator object,
# and then returns it.

  def opx_warn(tab)
    tab.validation_errors.each {|message| opx_print("** ERROR ** #{message}\n")}
    tab.validation_warnings.each {|message| opx_print("** WARNING ** #{message}\n")}
    tab
  end

# No Arguments
#
# Returns: <i>Boolean</i>
#
# Returns <i>true</i> iff the Tabulator state is EMPTY, as evidenced by the
# non-existence of the <tt><b>TABULATOR_COUNT_FILE</b></tt> .

  private
  def opx_empty?()
    ! opx_file_exist?(opx_file_prepend(TABULATOR_COUNT_FILE))
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

  def opx_file_process(file, type, key, fatal = false)
    etype = (fatal ? "Fatal" : "File")
    file = opx_file_prepend(file)
    datum = opx_file_read(file, fatal)
    if (!datum.is_a?(Hash))
      opx_err("#{etype} error, contents of #{type} not a Hash: #{file} #{datum.inspect}")
    elsif (!datum.keys.include?(key))
      opx_err("#{etype} error, Hash missing Key #{key} for #{type}: #{file}")
    elsif (opx_check_syntax(key, datum))
      datum
    else
      opx_err("#{etype} syntax error in #{type}: #{file}")
    end
  rescue
    opx_err("Fatal failure processing file: #{file}")
  end

# Arguments:
# * <i>file</i>: (<i>String</i>) file name
#
# Returns: <i>Boolean</i>
#
# Returns the result of calling File.exist? on the named <i>file</i>.
# Generates a Fatal error if any problems occur.

  def opx_file_exist?(file)
    File.exist?(file)
  rescue
    opx_err("Fatal failure of File.exist? for file: #{file}")
  end

# No Arguments
#
# Returns: N/A
#
# Backs up the Tabulator data in <tt><b>TABULATOR_COUNT_FILE</b></tt> to
# <tt><b>TABULATOR_BACKUP_FILE</b></tt>, by moving (renaming) the first file to
# the second.  Generates a Fatal error if any problems occur during the move.

  def opx_file_backup()
    FileUtils.mv(opx_file_prepend(TABULATOR_COUNT_FILE),
                 opx_file_prepend(TABULATOR_BACKUP_FILE))
  rescue
    opx_err("Fatal failure of FileUtils.mv to backup #{TABULATOR_COUNT_FILE}")
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

  def opx_file_prepend(file)
    ((File.directory?("Tabulator")) ? "Tabulator/#{file}" : file)
  rescue
    opx_err("Fatal failure of File.directory? for directory: Tabulator/")
  end

# Arguments:
# * <i>file</i>:  (<i>String</i>) file name
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

  def opx_file_read(file, fatal = false)
    if (opx_file_exist?(file))
      infile = opx_file_open_read(file, fatal)
      YAML::load(infile)
    else
      (fatal ?
       opx_err("Fatal failure, non-existent file: #{file}") :
       opx_err("File non-existent: #{file}"))
    end
  rescue
    (fatal ?
     opx_err("Fatal failure of YAML::load for file: #{file}") :
     opx_err("File read error in YAML::load for file: #{file}"))
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

  def opx_file_open_read(file, fatal = false)
    File.open(file, "r")
  rescue
    (fatal ?
     opx_err("Fatal failure of File.open for reading: #{file}") :
     opx_err("File open error while trying to read: #{file}"))
  end

# Arguments:
# * <i>file</i>: (<i>String</i>) file name
#
# Returns: <i>File Handle</i>
#
# Opens the <i>file</i> for writing and returns the resulting file handle.
# Generates a Fatal error if a problem occurs while opening the file.

  def opx_file_open_write(file)
    File.open(file, "w")
  rescue
    opx_err("Fatal failure of File.open for writing: #{file}")
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

  def opx_file_write_spreadsheet(tab)
    lines = tab.tabulator_spreadsheet()
    outfile = opx_file_open_write(opx_file_prepend(TABULATOR_SPREADSHEET_FILE))
    outfile.puts lines
    outfile.close()
    lines
  rescue
    opx_err("Fatal failure writing to spreadsheet file: #{file}")
  end

# Arguments:
# * <i>tab</i>: (<i>Class Object</i>) Tabulator object
#
# Returns: N/A
#
# Writes the current Tabulator data to <tt><b>TABULATOR_COUNT_FILE</b></tt>.
# Generates a Fatal error if problems occur while writing to the file.

  def opx_file_write_tabulator(tab)
    outfile = opx_file_open_write(opx_file_prepend(TABULATOR_COUNT_FILE))
    YAML::dump(tab.tabulator_count, outfile)
  rescue
    opx_err("Fatal failure of YAML::dump for file: #{TABULATOR_COUNT_FILE}")
  end

# No Arguments
#
# Returns: Tabulator Object
#
# Use the contents of the <tt><b>TABULATOR_COUNT_FILE</b></tt> to instantiate
# a new Tabulator object, which is returned.  Generates a Fatal error if there
# are any Tabulator validation errors or warnings, because this implies that
# Tabulator is in an inconsistent state.

  def opx_instantiate()
    file = TABULATOR_COUNT_FILE
    tc = opx_file_process(file, "Tabulator Count", "tabulator_count", true)
    tab = opx_new_tabulator(false, false, false, tc)
    opx_err("Fatal failure during Tabulator validation: #{file}") if
      (tab.validation_errors? || tab.validation_warnings?)
    tab
  rescue
    opx_err("Fatal failure during Tabulator instantiation")
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

  def opx_new_tabulator(jd, ed, file, tc)
    opx_warn(Tabulator.new(jd, ed, file, tc))
  rescue
    opx_err("Fatal failure of Tabulator.new(...)")
  end

# Arguments:
# * <i>key</i>  (<i>String</i>) Hash key expected in datum and used to identify the schema
# * <i>datum</i> (<i>Hash</i>) Tabulator input dataset to be syntax-checked against a built-in schema
#
# Returns: <i>Boolean</i>
#
# Returns <i>true</i> iff there are no errors resulting from syntax-checking
# the <i>datum</i> against the schema identified by the <i>key</i>.  Generates
# a Fatal error if any problems occur.

  def opx_check_syntax(key, datum)
    schema_file = opx_file_prepend("Schemas/#{key}_schema.yml")
    schema = opx_file_read(schema_file, true)
    if (CheckSyntaxYaml.new.check_syntax(schema, datum, true).length == 0)
      true
    else
      print "Datum: ",YAML::dump(datum),"\n" # DEBUG
      false
    end
  rescue
    opx_err("Fatal failure of CheckSyntaxYaml.new.check_syntax(...)")
  end

end

# Command-line interface for the Tabulator Operator.

begin
  operator = Operator.new
  operator.op_command(ARGV)
end
