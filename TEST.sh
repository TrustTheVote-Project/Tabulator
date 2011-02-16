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
    echo "ruby check_syntax_yaml_test.rb"
    ruby check_syntax_yaml_test.rb
    exitif
}

test_tab ()
{
    echo "ruby tabulator_test.rb"
    ruby tabulator_test.rb
    exitif
}

test_op ()
{
    echo "ruby xoperator_test.rb"
    ruby xoperator_test.rb
    exitif
}

test_val ()
{
    echo "ruby operator.rb reset"
    ruby operator.rb reset
    exitif
    echo "ruby operator.rb load Tests/Validation/JD.yml Tests/Validation/ED.yml OK"
    ruby operator.rb load Tests/Validation/JD.yml Tests/Validation/ED.yml OK
    exitif
    echo "ruby operator.rb add Tests/Validation/CC1.yml"
    ruby operator.rb add Tests/Validation/CC1.yml
    exitif
    echo "ruby operator.rb add Tests/Validation/CC2.yml"
    ruby operator.rb add Tests/Validation/CC2.yml
    exitif
    echo "ruby operator.rb add Tests/Validation/CC3.yml"
    ruby operator.rb add Tests/Validation/CC3.yml
    exitif
}

test_def ()
{
    echo "ruby operator.rb reset"
    ruby operator.rb reset
    exitif
    echo "ruby operator.rb load Tests/Default/JD.yml Tests/Default/ED.yml OK"
    ruby operator.rb load Tests/Default/JD.yml Tests/Default/ED.yml OK
    exitif
    echo "ruby operator.rb add Tests/Default/CC1.yml"
    ruby operator.rb add Tests/Default/CC1.yml
    exitif
    echo "ruby operator.rb add Tests/Default/CC2.yml"
    ruby operator.rb add Tests/Default/CC2.yml
    exitif
    echo "ruby operator.rb add Tests/Default/CC3.yml"
    ruby operator.rb add Tests/Default/CC3.yml
    exitif
}

test_def0 ()
{
    echo "ruby operator.rb reset"
    ruby operator.rb reset
    exitif
    echo "ruby operator.rb load Tests/Default/JD.yml Tests/Default/ED.yml OK"
    ruby operator.rb load Tests/Default/JD.yml Tests/Default/ED.yml OK
    exitif
}

test_def1 ()
{
    test_def0
    echo "ruby operator.rb add Tests/Default/CC1.yml"
    ruby operator.rb add Tests/Default/CC1.yml
    exitif
}

test_def2 ()
{
    test_def1
    echo "ruby operator.rb add Tests/Default/CC2.yml"
    ruby operator.rb add Tests/Default/CC2.yml
    exitif
}

test_all ()
{
    test_syn
    test_tab
    test_op
    test_def
    echo -e "!! ALL TABULATOR TESTS SUCCESSFUL !!\n"
    exit
}

if [ "$#" -eq 0 ]
then 
    test_all
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
tab*)
    test_tab
    exit
    ;;
op*)
    test_op
    exit
    ;;
val*)
    test_val
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
echo "Valid arguments are: all, syn(tax), tab(ulator), op(erator), def(ault), val(idation)"
exit 1
