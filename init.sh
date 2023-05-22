#! /bin/bash

if [ ! $(grep -q -E "^back:" /etc/group) ]; then
    groupadd back -r
fi

