#!/bin/bash

exitif () 
{ 
if [ "$?" -gt "0" ] 
then
  exit $?
fi
}

test_default ()
{
    ruby operator.rb
    exitif
    ruby operator.rb reset
    exitif
    ruby operator.rb Tests/Prototypical/ED.yml 
    exitif
    ruby operator.rb data
    exitif
    ruby operator.rb Tests/Prototypical/CC1.yml
    exitif
    ruby operator.rb state
    exitif
    ruby operator.rb Tests/Prototypical/CC2.yml
    exitif
    ruby operator.rb state
    exitif
    ruby operator.rb data
    exitif
    ruby operator.rb Tests/Prototypical/CC3.yml
    exitif
    ruby operator.rb state
    exitif
}

test_syntax ()
{
    ruby tab_schemas.rb
    exitif
}

test_dc ()
{
    ruby emgr_data_handler.rb
    exitif
    ruby operator.rb reset
    exitif
    ruby operator.rb EMGR_ELECTION_DEFINITION.yml
    exitif
}

test_va ()
{
    ruby emgr_data_handler.rb va
    exitif
    ruby operator.rb reset
    exitif
    ruby operator.rb EMGR_ELECTION_DEFINITION.yml
    exitif
}

test_bedrock ()
{
    ruby operator.rb reset
    exitif
    ruby operator.rb Tests/Bedrock/Bedrock_ED.yml
    exitif
    ruby operator.rb Tests/Bedrock/Bedrock_CC1.yml
    exitif
    ruby operator.rb state
    exitif
}

if [ "$#" -eq 0 ]
then 
    test_default
    exit 0
fi
case $1 in
all*)
    test_syntax
    test_default
    test_bedrock
    test_dc
    test_va
    echo -e "\n** ALL TABULATOR TESTS SUCCESSFUL**\n"
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
echo Valid arguments are: \<nothing\>, syntax, bedrock, dc, va, all
exit 1

