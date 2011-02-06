#!/bin/bash

exitif () 
{ 
if [ "$?" -gt "0" ] 
then
  exit $?
fi
}

test_tab ()
{
    ruby tabulator_test.rb
    exitif
}

test_all ()
{
    test_syntax
    test_default
    test_bedrock
    test_va
    test_dc
    echo -e "!! ALL TABULATOR TESTS SUCCESSFUL !!\n"
    exit
}

test_default ()
{
    ruby operator.rb reset
    ruby operator.rb test load Tests/Default/JD.yml Tests/Default/ED.yml 
    exitif
    #ruby operator.rb data
    #exitif
    ruby operator.rb add Tests/Default/CC1.yml
    exitif
    #ruby operator.rb state
    #exitif
    ruby operator.rb add Tests/Default/CC2.yml
    exitif
    #ruby operator.rb state
    #exitif
    #ruby operator.rb data
    #exitif
    ruby operator.rb add Tests/Default/CC3.yml
    exitif
    #ruby operator.rb state
    #exitif
}

test_def0 ()
{
    ruby operator.rb reset
    ruby operator.rb test load Tests/Default/JD.yml Tests/Default/ED.yml 
    exitif
}

test_def1 ()
{
    ruby operator.rb reset
    ruby operator.rb test load Tests/Default/JD.yml Tests/Default/ED.yml 
    exitif
    ruby operator.rb add Tests/Default/CC1.yml
    exitif
}

test_def2 ()
{
    ruby operator.rb reset
    ruby operator.rb test load Tests/Default/JD.yml Tests/Default/ED.yml 
    exitif
    ruby operator.rb add Tests/Default/CC1.yml
    exitif
    ruby operator.rb add Tests/Default/CC2.yml
    exitif
}

test_syntax ()
{
    ruby check_syntax_yaml_test.rb
    exitif
}

test_dc ()
{
    ruby emgr_data_handler.rb
    exitif
    ruby operator.rb reset
    exitif
    ruby operator.rb test load EMGR_JD.yml EMGR_ED.yml
    exitif
}

test_va ()
{
    ruby emgr_data_handler.rb va
    exitif
    ruby operator.rb reset
    exitif
    ruby operator.rb test load EMGR_JD.yml EMGR_ED.yml
    exitif
}

test_bedrock ()
{
    ruby operator.rb reset
    exitif
    ruby operator.rb test load Tests/Bedrock/Bedrock_JD.yml Tests/Bedrock/Bedrock_ED.yml
    exitif
    ruby operator.rb add Tests/Bedrock/Bedrock_CC1.yml
    exitif
    ruby operator.rb state
    exitif
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
    test_default
    exit
    ;;
syn*)
    test_syntax
    exit
    ;;
dc)
    test_dc
    exit
    ;;
va)
    test_va
    exit
    ;;
bed*)
    test_bedrock
    exit
    ;;
esac
echo Valid arguments are: \<nothing\>, all, syntax, tab, default, bedrock, dc, va
exit 1
