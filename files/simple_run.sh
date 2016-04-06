#!/bin/bash

#!/bin/sh

if [ "$#" -ne 1 ]; then
    echo "illegal number of parameters"
    # echo 'specify "scenario name" "From" "To"'
    echo 'specify the name of users'
    echo 'for example ./simple_run 10'
    exit 1
fi

erl -config priv/app -env ERL_FULLSWEEP_AFTER 2 -pa ./deps/*/ebin ./ebin -s amoc do mongoose_simple_soe2016 1 $1

