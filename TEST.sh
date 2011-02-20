#!/bin/bash

exitif () 
{ 
if [ "$?" -gt "0" ] 
then
  exit $?
else
  echo " "
fi
}

test_help ()
{
  echo " "
  echo "Valid args: help, syn(tax), val(idator), tab(ulator), op(erator), def(ault), all"
  echo " "
  echo "  help  what you are looking at"
  echo "   syn  run the unit tests for the Tabulator Syntax Checker"
  echo "   val  run the unit tests for the Tabulator Validator"
  echo "   tab  run the unit tests for the Tabulator Core"
  echo "    op  run the unit tests for the Tabulator Operator"
  echo "   def  run a default set of tests"
  echo "  def0  run the default tests to step 0 (load JD/ED)"
  echo "  def1  run the default tests to step 1 (load CC1)"
  echo "  def2  run the default tests to step 2 (load CC2)"
  echo "  def3  run the default tests to step 3 (load CC3)"
  echo "   all  run all the tests"
  echo "<none>  run all the unit tests"
  echo " "
}

test_syn ()
{
    echo "ruby -I . test/syntax_checker_test.rb"
    ruby -I . test/syntax_checker_test.rb
    exitif
}

test_tab ()
{
    echo "ruby -I . test/tabulator_test.rb"
    ruby -I . test/tabulator_test.rb
    exitif
}

test_val ()
{
    echo "ruby -I . test/validator_test.rb"
    ruby -I . test/validator_test.rb
    exitif
}

test_op ()
{
    echo "ruby -I . test/operator_test.rb"
    ruby -I . test/operator_test.rb
    exitif
}

test_def ()
{
    echo "ruby operator.rb reset"
    ruby operator.rb reset
    exitif
    echo "ruby operator.rb load data/Tests/Default/JD.yml data/Tests/Default/ED.yml OK"
    ruby operator.rb load data/Tests/Default/JD.yml data/Tests/Default/ED.yml OK
    exitif
    echo "ruby operator.rb add data/Tests/Default/CC1.yml"
    ruby operator.rb add data/Tests/Default/CC1.yml
    exitif
    echo "ruby operator.rb add data/Tests/Default/CC2.yml"
    ruby operator.rb add data/Tests/Default/CC2.yml
    exitif
    echo "ruby operator.rb add data/Tests/Default/CC3.yml"
    ruby operator.rb add data/Tests/Default/CC3.yml
    exitif
}

test_def0 ()
{
    echo "ruby operator.rb reset"
    ruby operator.rb reset
    exitif
    echo "ruby operator.rb load data/Tests/Default/JD.yml data/Tests/Default/ED.yml OK"
    ruby operator.rb load data/Tests/Default/JD.yml data/Tests/Default/ED.yml OK
    exitif
}

test_def1 ()
{
    test_def0
    echo "ruby operator.rb add data/Tests/Default/CC1.yml"
    ruby operator.rb add data/Tests/Default/CC1.yml
    exitif
}

test_def2 ()
{
    test_def1
    echo "ruby operator.rb add data/Tests/Default/CC2.yml"
    ruby operator.rb add data/Tests/Default/CC2.yml
    exitif
}

test_unit ()
{
    test_syn
    test_val
    test_tab
    test_op
    echo -e "!! ALL TABULATOR UNIT TESTS SUCCESSFUL !!\n"
    exit
}

test_all ()
{
    test_syn
    test_val
    test_tab
    test_op
    test_def
    echo -e "!! ALL TABULATOR TESTS SUCCESSFUL !!\n"
    exit
}

if [ "$#" -eq 0 ]
then 
    test_unit
    exit 0
fi
case $1 in
all*)
    test_all
    exit
    ;;
syn*)
    test_syn
    exit
    ;;
val*)
    test_val
    exit
    ;;
tab*)
    test_tab
    exit
    ;;
op*)
    test_op
    exit
    ;;
def0*)
    test_def0
    exit
    ;;
def1*)
    test_def1
    exit
    ;;
def2*)
    test_def2
    exit
    ;;
def*)
    test_def
    exit
    ;;
h*)
    test_help
    exit
    ;;
esac
echo "Invalid argument, try this: help"
exit 1
