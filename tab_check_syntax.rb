require "yaml"

def check_syntax(schema, datum)
  $check_syntax_error_codes = []
  check_syntax_internal(schema, datum, 0)
end

def check_syntax_internal(schema, datum, n) # n is depth of datum
  check_syntax_trace("check_syntax", schema, datum, n)
  if (schema.is_a?(String))
    check_syntax_string(schema, datum, n)
  elsif (schema.is_a?(Array))
    (datum.is_a?(Array) ?
     ((datum.length == 0) ||
      check_syntax_array(0, schema[0], datum, n)) :
     check_syntax_error(6, schema, datum))
  elsif (schema.is_a?(Hash))
    (datum.is_a?(Hash) ?
     check_syntax_hash(0, schema.keys, schema, datum, n) :
     check_syntax_error(7, schema, datum))
  else
    check_syntax_error(0, schema, datum)
  end
end

def check_syntax_string(schema, datum, n)
  check_syntax_trace('check_syntax_string', schema, datum, n)
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
       ((datum.is_a?(Integer) || datum.is_a?(String) || datum.is_a?(Date)) ||
        check_syntax_error(5, schema, datum)) :
       check_syntax_error(1, schema, datum))))))
end

def check_syntax_array(i, schema, datum, n) # i is array index
  check_syntax_trace("check_syntax_array#{i}", schema, datum, n)
  ((check_syntax_internal(schema, datum[i], n+1) ||
    check_syntax_error(8, schema, datum, i)) &&
    ((datum.length == i+1) || check_syntax_array(i+1, schema, datum, n)))
end

def check_syntax_hash(i, keys, schema, datum, n) # i is hash key index
  check_syntax_trace("check_syntax_hash#{i}", schema, datum, n)
  (check_syntax_hash_key(keys.shift, schema, datum, n+1) &&
   ((keys.length == 0) || check_syntax_hash(i+1, keys, schema, datum, n)))
end

def check_syntax_hash_key(key, schema, datum, n)
  check_syntax_trace("check_syntax_hash_#{key}", schema, datum, n)
  ((key =~ /^\|OR.*\|/) ?
   ((datum.key?(schema[key][0].keys[0])) ?
    ((datum.key?(schema[key][1].keys[0])) ?
     check_syntax_error(14, schema, datum) :
     (check_syntax_hash_key(schema[key][0].keys[0], schema[key][0], datum, n) ||
      check_syntax_error(13, schema, datum, "First"))) :
    ((datum.key?(schema[key][1].keys[0])) ?
     (check_syntax_hash_key(schema[key][1].keys[0], schema[key][1], datum, n) ||
      check_syntax_error(13, schema, datum, "Second")) :
     check_syntax_error(12, schema, datum))) :
   ((key =~ /^\|OPT.*\|/) ?
    ( ! datum.key?(schema[key].keys[0]) ||
     (check_syntax_hash_key(schema[key].keys[0], schema[key], datum, n) ||
      check_syntax_error(11, schema, datum))) :
    (datum.key?(key) ?
     (check_syntax_internal(schema[key], datum[key], n) ||
      check_syntax_error(10, schema, datum, key)) :
     check_syntax_error(9, schema, datum, key))))
end

$check_syntax_trace = false
$check_syntax_error_codes = []

def check_syntax_trace(tag, schema, datum, n)
  return unless $check_syntax_trace
  n.times { print "*" }
  print "* #{tag}\n  schema: #{schema.inspect}\n   datum: #{datum.inspect}\n"
end

def check_syntax_error_codes
  $check_syntax_error_codes
end

def check_syntax_error(errcode, schema, datum, extra = '')
  $check_syntax_error_codes.push(errcode)
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
    print "Hash key \'#{extra}\' not found in Datum"
  when 10
    print "Hash value Datum[#{extra}] of incorrect type"
  when 11
    print "OPT(ional) Hash value of incorrect type"
  when 12
    print "Failure to match either key in OR Hash"
  when 13
    print "#{extra} OR hash value of incorrect type"
  when 14
    print "Both keys present for OR hash"
  else
    print "Unknown error code: #{errcode}"
  end
  print "\n  Schema: #{schema.inspect}\n   Datum: #{datum.inspect}\n"
  false
end
