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

class CheckSyntaxYaml

# initialize
#
# Initializes three instance variables:
# * <i>@errors</i>:   [type Array] stack of Integer error codes for error trace back (initially empty)
# * <i>@trace</i>:    [type Boolean] indicates whether the syntax checker should perform tracing (initially <i>false</i>)
# * <i>@tracemax</i>: [type Integer] maximum number of characters of data to print while tracing (initially 300)

  def initialize
    @errors = []
    @trace = false
    @tracemax = 300
  end  
  
# check_syntax
#
# * <i>schema</i>: [type Arbitrary] schema to syntax-check against
# * <i>datum</i>:  [type Arbitrary] datum being checked
# * <i>trace</i>:  [type Boolean] trace flag (optional)
#
# Returns: Boolean
#
# The function check_syntax is the primary entry point into the
# CheckSyntaxYaml class.  It first sets up tracing (ensures tracing is ON when
# the <i>trace</i> flag is <i>true</i>, but does not override tracing when the
# <i>trace</i> flag <i>false</i>) and sets the error code stack to empty.  It
# then checks the validity of the <i>schema</i>, printing a fatal error
# message and returning <i>false</i> if invalid.  Finally, it initializes the
# data inspection depth to 0 and returns the result of syntax-checking the
# <i>datum</i> against the <i>schema</i>.

  def check_syntax(schema, datum, trace = false)
    @trace = trace unless @trace
    @errors = []
    unless (schema_is_valid?(schema))
      print "** FATAL ERROR ** Invalid schema: #{schema.inspect}\n"
      return false
    end
    check_syntax_internal(schema, datum, 0)
  end
  
# check_syntax_test
#
# This function is identical to check_syntax, except it does not check the validity of the
# schema, so it can be used for test cases involving invalid schemas.

  def check_syntax_test(schema, datum, trace = false)
    @trace = trace unless @trace
    @errors = []
    check_syntax_internal(schema, datum, 0)
  end
  
# check_syntax_internal
#
# * <i>schema</i>: [type Arbitrary] schema
# * <i>datum</i>:  [type Arbitrary] datum
# * <i>depth</i>:  [type Integer] current data inspection depth
# 
# Returns: Boolean
#
# The function check_syntax_internal is the internal top-level version of
# check_syntax (which is never called internally), and performs the actual
# recursive syntax-checking.  If the <i>schema</i> is a String,
# check_syntax_string checks the syntax.  Otherwise, the <i>schema</i> must be
# an Array or a Hash, and likewise for the <i>datum</i>, so either
# check_syntax_array or check_syntax_hash checks the syntax.

  def check_syntax_internal(schema, datum, depth)
    check_syntax_trace("check_syntax", schema, datum, depth)
    if (schema.is_a?(String))
      check_syntax_string(schema, datum, depth)
    elsif (schema.is_a?(Array))
      (datum.is_a?(Array) ?
       ((datum.length == 0) ||
        check_syntax_array(0, schema[0], datum, depth)) :
       check_syntax_error(6, schema, datum))
    elsif (schema.is_a?(Hash))
      (datum.is_a?(Hash) ?
       check_syntax_hash(0, schema.keys, schema, datum, depth) :
       check_syntax_error(7, schema, datum))
    else
      check_syntax_error(0, schema, datum)
    end
  end
  
# check_syntax_string
#
# * <i>schema</i>: [type String] schema
# * <i>datum</i>:  [type Arbitrary] datum
# * <i>depth</i>:  [type Integer] current data inspection depth
#
# Returns: Boolean
#
# The valid strings that may appear in a <i>schema</i> are as follows:
# * "Any":     matches any <i>datum</i>
# * "String":  matches any <i>datum</i> of type String or Date
# * "Integer": matches any <i>datum</i> of type Integer
# * "Date":    matches any <i>datum</i> of type String or Date
# * "Atomic":  matches any <i>datum</i> of type String, Integer, or Date
#
# All other schema strings are invalid and result in a syntax error, which may indicate the
# presence of an internal error, in that the schema being used is invalid.

  def check_syntax_string(schema, datum, depth)
    check_syntax_trace('check_syntax_string', schema, datum, depth)
    ((schema == datum) || (schema == "Any") ||
     ((schema == "String") ?
      ((datum.is_a?(String) || datum.is_a?(Date)) ||
       check_syntax_error(2, schema, datum)) :
      ((schema == "Integer") ?
       (datum.is_a?(Integer) ||
        check_syntax_error(3, schema, datum)) :
       ((schema == "Date") ?
        ((datum.is_a?(String) || datum.is_a?(Date)) ||
         check_syntax_error(4, schema, datum)) :
        ((schema == "Atomic") ?
         ((datum.is_a?(String) || datum.is_a?(Integer) || datum.is_a?(Date)) ||
          check_syntax_error(5, schema, datum)) :
         check_syntax_error(1, schema, datum))))))
  end
  
# check_syntax_array
#
# * <i>index</i>:  [type Integer] index of <i>datum</i> Array element being examined
# * <i>schema</i>: [type Arbitrary] schema
# * <i>datum</i>:  [type Array] datum
# * <i>depth</i>:  [type Integer] current data inspection depth
#
# Returns: Boolean
#
# Recursively check all elements in the Array <i>datum</i> to ensure they match the
# <i>schema</i>.

  def check_syntax_array(index, schema, datum, depth)
    check_syntax_trace("check_syntax_array#{index}", schema, datum, depth)
    ((check_syntax_internal(schema, datum[index], depth+1) ||
      check_syntax_error(8, schema, datum, index)) &&
     ((datum.length == index+1) || check_syntax_array(index+1, schema, datum, depth)))
  end
  
# check_syntax_hash
#
# * <i>index</i>:  [type Integer] index into <i>keys</i> Array
# * <i>keys</i>:   [type Array] of all keys for Hash <i>schema</i>
# * <i>schema</i>: [type Hash] schema
# * <i>datum</i>:  [type Hash] datum
# * <i>depth</i>:  [type Integer] current data inspection depth
#
# Returns: Boolean
#
# Recursively check all of the <i>keys</i> in the Hash <i>schema</i>, to ensure
# there is a match for each in the Hash <i>datum</i>.

  def check_syntax_hash(index, keys, schema, datum, depth)
    check_syntax_trace("check_syntax_hash#{index}", schema, datum, depth)
    (check_syntax_hash_key(keys.shift, schema, datum, depth+1) &&
     ((keys.length == 0) || check_syntax_hash(index+1, keys, schema, datum, depth)))
  end
  
# check_syntax_hash_key
#
# * <i>key</i>:    [type Arbitrary (but should be String)] key for syntax-checking Hash <i>datum</i>
# * <i>schema</i>: [type Hash] schema
# * <i>datum</i>:  [type Hash] datum
# * <i>depth</i>:  [type Integer] current data inspection depth
#
# Returns: Boolean
#
# There are three types of Hash schemas, all of whose keys must be of type String.  Two
# reserved types of strings are used to represent special cases when matching Hash keys: 
# * strings matching "|OPT.*|", for optional Hash keys, and
# * strings matching "|ALT.*|", for alternative Hash keys.  
# The reason for not just using either "|OPT|" or "|ALT|" is that there may
# be requirements for more than
# one such match within a single Hash schema, and Hash keys must be unique, so one may use
# "|OPT1|" and "|OPT2|", for instance, to disambiguate them.
#
# For OPT(ional)-keyed Hash schemas, the corresponding value in the schema is a single-keyed
# Hash that may or may not appear in the datum, but if it does, must match.
#
# For ALT(ernative)-keyed Hash schemas, the corresponding value in the schema is a dual-keyed
# Hash, one of whose keys and values must appear in the datum, and both of which may not.
#
# For all other Hash schemas, the Hash key must appear in the datum and the corresponding
# value must match.

  def check_syntax_hash_key(key, schema, datum, depth)
    check_syntax_trace("check_syntax_hash_#{key}", schema, datum, depth)
    ((!key.is_a?(String)) ?
     check_syntax_error(9, schema, datum, key) :
     ((key =~ /^\|ALT.*\|/) ?
      ((datum.key?(schema[key].keys[0])) ?
       ((datum.key?(schema[key].keys[1])) ?
        check_syntax_error(15, schema, datum) :
        (check_syntax_hash_key(schema[key].keys[0], schema[key], datum, depth) ||
         check_syntax_error(14, schema, datum, "First"))) :
       ((datum.key?(schema[key].keys[1])) ?
        (check_syntax_hash_key(schema[key].keys[1], schema[key], datum, depth) ||
         check_syntax_error(14, schema, datum, "Second")) :
        check_syntax_error(13, schema, datum))) :
      ((key =~ /^\|OPT.*\|/) ?
       ( ! datum.key?(schema[key].keys[0]) ||
         (check_syntax_hash_key(schema[key].keys[0], schema[key], datum, depth) ||
          check_syntax_error(12, schema, datum))) :
       (datum.key?(key) ?
        (check_syntax_internal(schema[key], datum[key], depth) ||
         check_syntax_error(11, schema, datum, key)) :
        check_syntax_error(10, schema, datum, key)))))
  end
  
# check_syntax_trace
#
# * <i>context</i>: [type String] holds the calling context
# * <i>schema</i>:  [type Arbitrary] schema
# * <i>datum</i>:   [type Arbitrary] datum
# * <i>depth</i>:   [type Integer] current data inspection depth
# 
# Returns: N/A
#
# Operates only when tracing is ON, by printing the inspection <i>depth</i> and the values
# of the <i>schema</i> and <i>datum</i> items (printout is character-limited to
# <i>@tracemax</i> characters for each item).

  def check_syntax_trace(context, schema, datum, depth)
    return unless @trace
    depth.times { print "*" }
    print "* #{context}\n  schema: #{schema.inspect[0 .. @tracemax]}\n"
    print "   datum: #{datum.inspect[0 .. @tracemax]}\n"
  end
  
# check_syntax_error
#
# * <i>errcode</i>: [type Integer] error code
# * <i>schema</i>:  [type Arbitrary] schema
# * <i>datum</i>:   [type Arbitrary] datum
# * <i>extra</i>:   [type String] extra error-printing information (optional)
# 
# Returns: <i>false</i>
# 
# Called when a syntax error is discovered.  Pushes the <i>errcode</i> onto the
# <i>@errors</i> error code stack, prints an error message (potentially utilizing the
# optional <i>extra</i> argument), and then prints the values of the mismatched
# <i>schema</i> and <i>data</i> items (printout is character-limited to <i>@tracemax</i>
# characters for each item).
#
# When a syntax error is discovered, error codes are stacked onto <i>@errors</i>, via
# repeated calls to check_syntax_error, as the syntax checker recursively unwinds. 
# Error stacking permits the testing of other than 1st-level errors, like 2nd-level,
# 3rd-level, etc.

  def check_syntax_error(errcode, schema, datum, extra = '')
    @errors.push(errcode)
    print "\n**SYNTAX ERROR \##{errcode}** "
    case errcode
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
    print "\n  Schema: #{schema.inspect[0 .. @tracemax]}"
    print "\n   Datum: #{datum.inspect[0 .. @tracemax]}\n"
    false
  end

# error_stack
#
# Returns: <i>@errors</i>
#
# Returns the current value of the <i>@errors</i> error stack.

  def error_stack()
    @errors
  end

# trace_set
#
# * <i>onoff</i>: [type Boolean] value turns tracing ON or OFF
#
# Returns: <i>@trace</i>
#
# Turns tracing ON or OFF by setting <i>@trace</i> to <i>true</i> or <i>false</i>.

  def trace_set(onoff)
    @trace = (onoff ? true : false)
    @trace
  end
  
# trace_max
#
# * <i>number</i>: [type Integer] number of characters for limiting trace output
#
# Returns: <i>@tracemax</i>
#
# Regulates the maximum amount of traced data output (wrt number of characters of data
# printed), by setting <i>@tracemax</i> to the maximum of <i>number</i> and 10
# (ensuring at least a minimal amount of tracing).  Used by check_syntax_trace,
# check_syntax_error, and schema_valid_trace.

  def trace_max(number)
    @tracemax = [number, 10].max
    @tracemax
  end
  
# schema_is_valid?
#
# * <i>schema</i>: [type Arbitrary] schema
#
# Returns: Boolean
#
# A <i>schema</i> is a data structure comprised of Strings, Arrays, Hashes, and
# combinations thereof, and nothing else.  The function schema_is_valid? returns
# <i>true</i> only when the <i>schema</i> has a valid format.

  def schema_is_valid?(schema)
    schema_valid_trace("schema_is_valid?", schema)
    ((schema.is_a?(String)) ?
     (["Integer", "String", "Date", "Atomic", "Any"].include?(schema) ||
      schema_not_valid(schema, "String not recognized")) :
     ((schema.is_a?(Array)) ?
      schema_is_valid_array?(schema) :
      ((schema.is_a?(Hash)) ?
       schema_is_valid_hash?(schema) :
       schema_not_valid(schema, "Type #{schema.class} not used in Schemas"))))
  end
  
# schema_is_valid_array?
#
# * <i>schema</i>: [type Array] schema
#
# Returns: Boolean
#
# A <i>schema</i> of type Array is valid only if it has one element and that element is
# a valid schema.

  def schema_is_valid_array?(schema)
    schema_valid_trace("schema_is_valid_array?", schema)
    ((schema.length == 1) ?
     schema_is_valid?(schema[0]) :
     schema_not_valid(schema, "Array not of length 1"))
  end
  
# schema_is_valid_hash?
#
# * <i>schema</i>: [type Hash] schema
#
# Returns: Boolean
#
# A <i>schema</i> of type Hash is valid only each of its <i>key,value</i>
# pairs is valid. 

  def schema_is_valid_hash?(schema)
    schema_valid_trace("schema_is_valid_hash?", schema)
    schema.each do |key, value|
      return false unless schema_is_valid_key_value?(key, value)
    end
  end
  
# schema_is_valid_key_value?
#
# * <i>key</i>:   [type Arbitrary] Hash key
# * <i>value</i>: [type Arbitrary] Hash value
#
# Returns: Boolean
#
# A Hash <i>key,value</i> pair is valid if the key is a String and the value is a valid
# schema.  But there are two special types of keys, as documented under check_syntax_hash_key: 
# * keys matching "|OPT.*|", in which case the value must be a single-keyed Hash (the option), and
# * keys matching "|ALT.*|", in which case the value must be a dual-keyed Hash (the alternatives).
#
# OPT(ional) schema keys permit schemas to match data with an optional Hash key.
#
# ALT(ernative) schema keys permit schemas to match data with one or another alternative
# Hash keys, but not both.

  def schema_is_valid_key_value?(key, value)
    schema_valid_trace("schema_is_valid_key_value?", value, key)
    ((key.is_a?(String)) ?
     ((key =~ /^\|OPT.*\|/) ?
      ((value.is_a?(Hash) && (value.keys.length == 1)) ?
       schema_is_valid_hash?(value) :
       schema_not_valid(value, "Value not 1-keyed Hash", key)) :
      ((key =~ /^\|ALT.*\|/) ?
       ((value.is_a?(Hash) && (value.keys.length == 2)) ?
        schema_is_valid_hash?(value) :
        schema_not_valid(value, "Value not 2-keyed Hash", key)) :
       schema_is_valid?(value))) :
     schema_not_valid(value, "Key not a String", key))
  end
  
# schema_not_valid
#
# * <i>schema</i>:  [type Arbitrary] schema
# * <i>message</i>: [type String] error message
# * <i>key</i>:     [type Hash] key (optional)
#
# Returns: <i>false</i>
#
# Prints an INVALID SCHEMA error message and returns <i>false</i>.

  def schema_not_valid(schema, message, key = '')
    print "\n** INVALID SCHEMA ** #{key.inspect} #{message}: #{schema.inspect}\n"
    false
  end
  
# schema_valid_trace
#
# * <i>context</i>: [type String] holds the calling context
# * <i>schema</i>:  [type Arbitrary] schema
# * <i>key</i>:     [type Hash] key (optional)
# 
# Returns: N/A
#
# Operates only when tracing is ON, by printing the calling <i>context</i>, the optional
# Hash <i>key</i>, and the <i>schema</i> (printout is character-limited to
# <i>@tracemax</i> characters for the schema).

  def schema_valid_trace(context, schema, key = '')
    return unless @trace
    print "#{context}: #{key.inspect} #{schema.inspect[0 .. @tracemax]}\n"
  end

end
