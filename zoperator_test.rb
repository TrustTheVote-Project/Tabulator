#!/usr/bin/ruby

require "operator"

begin
  cmds = ["reset",
          "load Tests/Validation/JD.yml Tests/Validation/ED.yml OK",
          "check"]
  cmds.each do |cmd|
    print "Testing Operator Command: #{cmd}\n"
    raise StandardError unless ("" == Operator.new.op_command(cmd.split(/ /)))
  end
rescue
  print "Commands:\n"
  cmds.each {|cmd| print("ruby operator.rb #{cmd}\n")}
end
