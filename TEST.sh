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
    ruby check_syntax_yaml_test.rb
    exitif
}

test_tab ()
{
    ruby tabulator_test.rb
    exitif
}

test_def ()
{
    ruby operator.rb reset
    exitif
    ruby operator.rb load Tests/Default/JD.yml Tests/Default/ED.yml OK
    exitif
    ruby operator.rb add Tests/Default/CC1.yml
    exitif
    ruby operator.rb add Tests/Default/CC2.yml
    exitif
    ruby operator.rb add Tests/Default/CC3.yml
    exitif
}

test_def0 ()
{
    ruby operator.rb reset
    exitif
    ruby operator.rb load Tests/Default/JD.yml Tests/Default/ED.yml OK
    exitif
}

test_def1 ()
{
    test_def0
    ruby operator.rb add Tests/Default/CC1.yml
    exitif
}

test_def2 ()
{
    test_def1
    ruby operator.rb add Tests/Default/CC2.yml
    exitif
}

test_all ()
{
    test_syn
    test_tab
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
echo "Valid arguments are: all, syn(tax), tab(ulator), def(ault)"
exit 1
