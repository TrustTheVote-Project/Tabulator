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

test_syn ()
{
    echo "ruby -I . test/check_syntax_yaml_test.rb"
    ruby -I . test/check_syntax_yaml_test.rb
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
esac
echo "Valid args: all, syn(tax), val(idator), tab(ulator), op(erator), def(ault)"
exit 1
