# OSDV Tabulator - YAML Syntax Checker for TTV CDF Datasets
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

require "yaml"

# The CheckSyntaxYaml class provides a Yaml Syntax Checker for the Tabulator,
# which checks the syntax of TTV Common Data Format (CDF) datasets provided as
# input to the Tabulator.

class CheckSyntaxYaml

# TRACE_DEFAULT is an <i>Integer</i> constant (300) that holds the default
# setting for character-limited printing while tracing output.

  TRACE_DEFAULT = 300

  attr_accessor :errors

# Arguments:
# * <i>schema</i>: (<i>Arbitrary</i>) schema to syntax-check against
# * <i>datum</i>:  (<i>Arbitrary</i>) datum being checked
# * <i>trace</i>:  (<i>Integer</i>) limits tracing of output (optional, default 300 characters)
#
# Returns: <i>errors</i> <i>Array</i> 
#
# The function check_syntax is the primary entry point into the
# CheckSyntaxYaml class.  It first sets the error code stack to empty.  It
# then checks the validity of the <i>schema</i>, and if invalid, generates a
# syntax error and returns the error code stack [-1].  Finally, it initializes
# the data inspection depth to 0, checks the syntax of the <i>datum</i>
# against the <i>schema</i>, and returns the resulting error code stack, which
# will be empty if the check succeeds, non-empty if it fails.
#
# The optional <i>trace</i> value limits tracing of output, and is consumed by
# the functions check_syntax_trace, check_syntax_error, and
# schema_is_valid_trace.  When <i>trace</i> is negative, calls to all
# syntax-checking and schema-validity-checking functions in this library are
# traced, and the amount of output generated is limited to <i>trace.abs</i>
# characters of output per item printed.  When positive, it acts similarly to
# limit the output printed by check_syntax_error.

  def check_syntax(schema, datum, validate = true, trace = TRACE_DEFAULT)
    self.errors = []
    if (validate && !schema_is_valid?(schema))
      check_syntax_error(-1, schema, datum, trace)
    else
      check_syntax_internal(schema, datum, 0, trace)
    end
    self.errors
  end

# Arguments:
# * <i>schema</i>: (<i>Arbitrary</i>) schema
# * <i>datum</i>:  (<i>Arbitrary</i>) datum
# * <i>depth</i>:  (<i>Integer</i>) current data inspection depth
# * <i>trace</i>:  (<i>Integer</i>) limits tracing of output
# 
# Returns: <i>Boolean</i>
#
# The function check_syntax_internal is the internal top-level version of
# check_syntax (which is never called internally), and performs the actual
# recursive syntax-checking.  If the <i>schema</i> is a <i>String</i>,
# check_syntax_string checks the syntax.  Otherwise, the <i>schema</i> must be
# an <i>Array</i> or a <i>Hash</i>, and likewise for the <i>datum</i>, so either
# check_syntax_array or check_syntax_hash checks the syntax.

  private
  def check_syntax_internal(schema, datum, depth, trace)
    check_syntax_trace("check_syntax", schema, datum, depth, trace)
    if (schema.is_a?(String))
      check_syntax_string(schema, datum, depth, trace)
    elsif (schema.is_a?(Array))
      (datum.is_a?(Array) ?
       ((datum.length == 0) ||
        check_syntax_array(0, schema[0], datum, depth, trace)) :
       check_syntax_error(6, schema, datum, trace))
    elsif (schema.is_a?(Hash))
      (datum.is_a?(Hash) ?
       check_syntax_hash(0, schema.keys, schema, datum, depth, trace) :
       check_syntax_error(7, schema, datum, trace))
    else
      check_syntax_error(0, schema, datum, trace)
    end
  end
  
# Arguments:
# * <i>schema</i>: (<i>String</i>) schema
# * <i>datum</i>:  (<i>Arbitrary</i>) datum
# * <i>depth</i>:  (<i>Integer</i>) current data inspection depth
# * <i>trace</i>:  (<i>Integer</i>) limits tracing of output
#
# Returns: <i>Boolean</i>
#
# The valid strings that may appear in a <i>schema</i> are as follows:
# * "Any":     matches any <i>datum</i>
# * "String":  matches any <i>datum</i> of type <i>String</i> or <i>Date</i>
# * "Integer": matches any <i>datum</i> of type <i>Integer</i>
# * "Date":    matches any <i>datum</i> of type <i>String</i> or <i>Date</i>
# * "Atomic":  matches any <i>datum</i> of type <i>String</i>, <i>Integer</i>, or <i>Date</i>
#
# All other schema strings are invalid and result in a syntax error, which may
# indicate the presence of an internal error, in that the schema being used is
# invalid.

  def check_syntax_string(schema, datum, depth, trace)
    check_syntax_trace('check_syntax_string', schema, datum, depth, trace)
    ((schema == datum) || (schema == "Any") ||
     ((schema == "String") ?
      ((datum.is_a?(String) || datum.is_a?(Date)) ||
       check_syntax_error(2, schema, datum, trace)) :
      ((schema == "Integer") ?
       (datum.is_a?(Integer) ||
        check_syntax_error(3, schema, datum, trace)) :
       ((schema == "Date") ?
        ((datum.is_a?(String) || datum.is_a?(Date)) ||
         check_syntax_error(4, schema, datum, trace)) :
        ((schema == "Atomic") ?
         ((datum.is_a?(String) || datum.is_a?(Integer) || datum.is_a?(Date)) ||
          check_syntax_error(5, schema, datum, trace)) :
         check_syntax_error(1, schema, datum, trace))))))
  end
  
# Arguments:
# * <i>index</i>:  (<i>Integer</i>) index of <i>datum</i> <i>Array</i> element being examined
# * <i>schema</i>: (<i>Arbitrary</i>) schema
# * <i>datum</i>:  (<i>Array</i>) datum
# * <i>depth</i>:  (<i>Integer</i>) current data inspection depth
# * <i>trace</i>:  (<i>Integer</i>) limits tracing of output
#
# Returns: <i>Boolean</i>
#
# Recursively check all elements in the <i>Array</i> <i>datum</i> to ensure they
# match the <i>schema</i>.  Under our syntax-checking regime, for each
# individual data array, all array elements must have the same type and match
# the same schema.

  def check_syntax_array(index, schema, datum, depth, trace)
    check_syntax_trace("check_syntax_array#{index}", schema, datum, depth, trace)
    ((check_syntax_internal(schema, datum[index], depth+1, trace) ||
      check_syntax_error(8, schema, datum, trace, index)) &&
     ((datum.length == index+1) || check_syntax_array(index+1, schema, datum, depth, trace)))
  end
  
# Arguments:
# * <i>index</i>:  (<i>Integer</i>) index into <i>keys</i> <i>Array</i>
# * <i>keys</i>:   (<i>Array</i>) of all keys for <i>Hash</i> <i>schema</i>
# * <i>schema</i>: (<i>Hash</i>) schema
# * <i>datum</i>:  (<i>Hash</i>) datum
# * <i>depth</i>:  (<i>Integer</i>) current data inspection depth
# * <i>trace</i>:  (<i>Integer</i>) limits tracing of output
#
# Returns: <i>Boolean</i>
#
# Recursively check all of the <i>keys</i> in the <i>Hash</i> <i>schema</i>, to ensure
# there is a match for each in the <i>Hash</i> <i>datum</i>.

  def check_syntax_hash(index, keys, schema, datum, depth, trace)
    check_syntax_trace("check_syntax_hash#{index}", schema, datum, depth, trace)
    (check_syntax_hash_key(keys.shift, schema, datum, depth+1, trace) &&
     ((keys.length == 0) || check_syntax_hash(index+1, keys, schema, datum, depth, trace)))
  end
  
# Arguments:
# * <i>key</i>:    (<i>Atomic</i>) key for syntax-checking <i>Hash</i> <i>datum</i>
# * <i>schema</i>: (<i>Hash</i>) schema
# * <i>datum</i>:  (<i>Hash</i>) datum
# * <i>depth</i>:  (<i>Integer</i>) current data inspection depth
# * <i>trace</i>:  (<i>Integer</i>) limits tracing of output
#
# Returns: <i>Boolean</i>
#
# There are three types of <i>Hash</i> schemas, all of whose keys must be of type
# <i>String</i>.  Two reserved types of strings are used to represent special cases
# when matching <i>Hash</i> keys:
# * strings matching "|OPT.*|", for optional <i>Hash</i> keys, and
# * strings matching "|ALT.*|", for alternative <i>Hash</i> keys.  
# The reason for not just using either "|OPT|" or "|ALT|" is that there may be
# requirements for more than one such match within a single <i>Hash</i> schema, and
# <i>Hash</i> keys must be unique, so one may use "|OPT1|" and "|OPT2|", for
# instance, to disambiguate them.
#
# For OPT(ional)-keyed <i>Hash</i> schemas, the corresponding value in the schema is
# a single-keyed <i>Hash</i> that may or may not appear in the datum, but if it does,
# must match.
#
# For ALT(ernative)-keyed <i>Hash</i> schemas, the corresponding value in the schema
# is a dual-keyed <i>Hash</i>, one of whose keys and values must appear in the datum,
# and both of which may not.
#
# For all other <i>Hash</i> schemas, the <i>Hash</i> key must appear in the datum and the
# corresponding value must match.

  def check_syntax_hash_key(key, schema, datum, depth, trace)
    check_syntax_trace("check_syntax_hash_#{key}", schema, datum, depth, trace)
    ((!key.is_a?(String)) ?
     check_syntax_error(9, schema, datum, trace, key) :
     ((key =~ /^\|ALT.*\|/) ?
      ((datum.key?(schema[key].keys[0])) ?
       ((datum.key?(schema[key].keys[1])) ?
        check_syntax_error(15, schema, datum, trace) :
        (check_syntax_hash_key(schema[key].keys[0], schema[key], datum, depth, trace) ||
         check_syntax_error(14, schema, datum, trace, "First"))) :
       ((datum.key?(schema[key].keys[1])) ?
        (check_syntax_hash_key(schema[key].keys[1], schema[key], datum, depth, trace) ||
         check_syntax_error(14, schema, datum, trace, "Second")) :
        check_syntax_error(13, schema, datum, trace))) :
      ((key =~ /^\|OPT.*\|/) ?
       ( ! datum.key?(schema[key].keys[0]) ||
         (check_syntax_hash_key(schema[key].keys[0], schema[key], datum, depth, trace) ||
          check_syntax_error(12, schema, datum, trace))) :
       (datum.key?(key) ?
        (check_syntax_internal(schema[key], datum[key], depth, trace) ||
         check_syntax_error(11, schema, datum, trace, key)) :
        check_syntax_error(10, schema, datum, trace, key)))))
  end
  
# Arguments:
# * <i>context</i>: (<i>String</i>) holds the calling context
# * <i>schema</i>:  (<i>Arbitrary</i>) schema
# * <i>datum</i>:   (<i>Arbitrary</i>) datum
# * <i>depth</i>:   (<i>Integer</i>) current data inspection depth
# * <i>trace</i>:   (<i>Integer</i>) limits tracing of output
# 
# Returns: N/A
#
# Operates only when the  <i>trace</i> limit is negative, by printing the
# inspection <i>depth</i> and the values of the <i>schema</i> and <i>datum</i>
# items (printout is character-limited to <i>trace.abs</i> characters for each
# item).

  def check_syntax_trace(context, schema, datum, depth, trace)
    return unless trace < 0
    depth.times { print "*" }
    print "* #{context}\n  schema: #{schema.inspect[0 .. trace.abs]}\n"
    print "   datum: #{datum.inspect[0 .. trace.abs]}\n"
  end

# Arguments:
# * <i>errcode</i>: (<i>Integer</i>) error code
# * <i>schema</i>:  (<i>Arbitrary</i>) schema
# * <i>datum</i>:   (<i>Arbitrary</i>) datum
# * <i>trace</i>:   (<i>Integer</i>) limits tracing of output
# * <i>extra</i>:   (<i>String</i>) extra error-printing information (optional, default '')
# 
# Returns: <i>false</i>
# 
# Called when a syntax error is discovered.  Pushes the <i>errcode</i> onto
# the <i>errors</i> error code stack, prints a SYNTAX ERROR message
# (potentially utilizing the optional <i>extra</i> argument), and then prints
# the values of the mismatched <i>schema</i> and <i>data</i> items (printout
# is character-limited to <i>trace.abs</i> characters per item).
#
# When a syntax error is discovered, error codes are stacked onto
# <i>errors</i>, via repeated calls to check_syntax_error, as the syntax
# checker recursively unwinds.  Error stacking permits the testing of other
# than 1st-level errors, e.g., 2nd-level, 3rd-level, etc.

  def check_syntax_error(errcode, schema, datum, trace, extra = '')
    self.errors.push(errcode)
    print "\n**SYNTAX ERROR \##{errcode}** "
    case errcode
    when -1
      print "Invalid schema: #{schema.inspect[0 .. trace.abs]}"
    when 0
      print "Schema type \'#{schema.class}\' not handled"
    when 1
      print "Schema string \'#{schema}\' not handled"
    when 2
      print "Datum not a String"
    when 3
      print "Datum not an Integer"
    when 4
      print "Datum not a Date"
    when 5
      print "Datum not Atomic"
    when 6
      print "Datum not an Array (Sequence)"
    when 7
      print "Datum not a Hash (Dictionary)"
    when 8
      print "Array element Datum[#{extra}] of incorrect type"
    when 9
      print "Schema Hash Key \'#{extra}\' not of String type"
    when 10
      print "Hash key \'#{extra}\' not found in Datum"
    when 11
      print "Hash value Datum[#{extra}] of incorrect type"
    when 12
      print "OPT(ional) Hash value of incorrect type"
    when 13
      print "Failure to match either key in ALT(ernative) Hash"
    when 14
      print "#{extra} ALT(ernative) hash value of incorrect type"
    when 15
      print "Both keys present for ALT(ernative) hash"
    else
      print "Unknown error code: #{errcode}"
    end
    print "\n  Schema: #{schema.inspect[0 .. trace.abs]}"
    print "\n   Datum: #{datum.inspect[0 .. trace.abs]}\n"
    false
  end

# Arguments:
# * <i>schema</i>: (<i>Arbitrary</i>) schema
# * <i>trace</i>:  (<i>Integer</i>) limits tracing of output (optional, default 300 characters)
#
# Returns: <i>Boolean</i>
#
# A <i>schema</i> is a data structure comprised of Strings, Arrays, Hashes,
# and combinations thereof, and nothing else.  The function schema_is_valid?
# returns <i>true</i> only when the <i>schema</i> has a valid format.
#
# If the schema is a <i>String</i>, it must be one of (Integer, String, Date,
# Atomic, Any).  If the schema is an <i>Array</i>, schema_is_valid_array? is called
# to perform the validity check. If the schema is a <i>Hash</i>,
# schema_is_valid_hash?  is called to perform the validity check. No other
# types of schemas are valid.

  public
  def schema_is_valid?(schema, trace = TRACE_DEFAULT)
    schema_is_valid_trace("schema_is_valid?", schema, trace)
    ((schema.is_a?(String)) ?
     (["Integer", "String", "Date", "Atomic", "Any"].include?(schema) ||
      schema_not_valid(schema, "Schema string not recognized", trace)) :
     ((schema.is_a?(Array)) ?
      schema_is_valid_array?(schema, trace) :
      ((schema.is_a?(Hash)) ?
       schema_is_valid_hash?(schema, trace) :
       schema_not_valid(schema, "Schema type #{schema.class} invalid", trace))))
  end    

# Arguments:
# * <i>schema</i>: (<i>Array</i>) schema
# * <i>trace</i>:  (<i>Integer</i>) limits tracing of output
#
# Returns: <i>Boolean<i>
#
# A <i>schema</i> of type <i>Array</i> is valid only if it has one element and
# that element is a valid schema.  This provision limits the type of
# acceptable data arrays to those whose elements all have the same type and
# match the same schema.

  private
  def schema_is_valid_array?(schema, trace)
    schema_is_valid_trace("schema_is_valid_array?", schema, trace)
    ((schema.length == 1) ?
     schema_is_valid?(schema[0], trace) :
     schema_not_valid(schema, "Schema array not of length 1", trace))
  end
  
# Arguments:
# * <i>schema</i>: (<i>Hash</i>) schema
# * <i>trace</i>:  (<i>Integer</i>) limits tracing of output
#
# Returns: <i>Boolean<i>
#
# A <i>schema</i> of type <i>Hash</i> is valid only each of its <i>key,value</i>
# pairs is valid. 

  def schema_is_valid_hash?(schema, trace)
    schema_is_valid_trace("schema_is_valid_hash?", schema, trace)
    schema.each do |key, value|
      return false unless schema_is_valid_key_value?(key, value, trace)
    end
    true
  end
  
# Arguments:
# * <i>key</i>:   (<i>Arbitrary</i>) <i>Hash</i> key
# * <i>value</i>: (<i>Arbitrary</i>) <i>Hash</i> value
# * <i>trace</i>:  (<i>Integer</i>) limits tracing of output
#
# Returns: <i>Boolean</i>
#
# A <i>Hash</i> <i>key,value</i> pair is valid if the <i>key</i> is a <i>String</i> and the
# value is a valid schema.  But there are two special types of keys, as
# documented under check_syntax_hash_key:
# * keys matching "|OPT.*|", in which case the value must be a single-keyed <i>Hash</i> (the option), and
# * keys matching "|ALT.*|", in which case the value must be a dual-keyed <i>Hash</i> (the alternatives).
#
# OPT(ional) schema keys permit schemas to match data with an optional <i>Hash</i> key.
#
# ALT(ernative) schema keys permit schemas to match data with one or another
# alternative <i>Hash</i> keys, but not both.

  def schema_is_valid_key_value?(key, value, trace)
    schema_is_valid_trace("schema_is_valid_key_value?", value, trace, key)
    ((key.is_a?(String)) ?
     ((key =~ /^\|OPT.*\|/) ?
      ((value.is_a?(Hash) && (value.keys.length == 1)) ?
       schema_is_valid_hash?(value, trace) :
       schema_not_valid(value, "Schema OPT value not 1-keyed Hash", trace)) :
      ((key =~ /^\|ALT.*\|/) ?
       ((value.is_a?(Hash) && (value.keys.length == 2)) ?
        schema_is_valid_hash?(value, trace) :
        schema_not_valid(value, "Schema ALT Value not 2-keyed Hash", trace)) :
       schema_is_valid?(value, trace))) :
     schema_not_valid(key, "Schema key not of type String", trace))
  end
  
# Arguments:
# * <i>schema</i>:  (<i>Arbitrary</i>) schema
# * <i>message</i>: (<i>String</i>) error message
# * <i>trace</i>:   (<i>Integer</i>) limits tracing of output
#
# Returns: <i>false</i>
#
# Prints an INVALID SCHEMA error message and returns <i>false</i>.

  def schema_not_valid(schema, message, trace)
    print "\n** INVALID SCHEMA ** #{message}: #{schema.inspect}\n"
    false
  end
  
# Arguments:
# * <i>context</i>: (<i>String</i>) holds the calling context
# * <i>schema</i>:  (<i>Arbitrary</i>) schema
# * <i>trace</i>:   (<i>Integer</i>) limits tracing of output
# * <i>key</i>:     (<i>Hash</i>) key (optional, default '')
# 
# Returns: N/A
#
# Operates only when the <i>trace</i> limit is negative, by printing the
# calling <i>context</i>, the optional <i>Hash</i> <i>key</i>, and the
# <i>schema</i> (whose printout is character-limited to <i>trace.abs</i>
# characters).

  def schema_is_valid_trace(context, schema, trace, key = '')
    return unless trace < 0
    if (key == '')
      print "#{context}: #{schema.inspect[0 .. trace.abs]}\n"
    else
      print "#{context}: #{key.to_s} #{schema.inspect[0 .. trace.abs]}\n"
    end
  end

end
