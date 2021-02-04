#!/bin/bash

function usage {
        echo "Usage: $0 [-p sshport] [-s sshpassword] fnethost [baseline-config-file]"
        echo "       $0 fnethost"
        echo "          - Fetches config from fnethost and writes it to text file fnethost_baseline.txt"
        echo ""            
        echo "       OPTIONS:"
        echo "          -p sshport              Sets SSH port to something different than the default number 22"
        echo "          -s sshpassword          Sets SSH password when public key auth not available. Requires sshpass."
        echo "          baseline-config-file    Fetches config from fnethost and compares it to config file baseline-config-file"
        exit 1
}

# Default SSH port unless specified in option
sshport=22;
s_pwd_used=0;

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

while getopts "h?p:s:" opt; do
    case "$opt" in
    h|\?)
        usage
        ;;
    p)  sshport=$OPTARG
        ;;
    s)  sshpwd=$OPTARG
        s_pwd_used=1;
        ;;
    :)  echo "Invalid option: -$OPTARG requires an argument" 1>&2
        exit 0
        ;;
    *)  echo "Unimplemented option: -$OPTARG" >&2; exit 1;;
    esac    
done

shift $((OPTIND-1))

echo "Debug: first $1 second $2 port $sshport pwd $sshpwd"

# validate input parameters

# check number of args (non-options): $#

if [[ $# > 2 ]] || [[ $# < 1 ]] ; then
    usage
fi

if [[ $sshport < 1 ]] || [[ $sshport > 65535 ]] ; then
    echo "Invalid SSH port chosen: $sshport. Valid range: 1-65535"
    exit 1
fi

if [[ $s_pwd_used -eq 1 ]] ; then
    sshpass > /dev/null 2>&1
    if [[ $? == 127 ]] ; then
        echo "sshpass is required to run this script, when using the -s sshpassword option."
        exit 1
    fi
else
    # Check that the user default user key has been added to target host. If not, add it.
    ssh -p $sshport -q -o "BatchMode=yes" $1 exit 0
    return_code=$?
    echo "return code = $return_code"
    if [[ $return_code -ne 0 ]] ; then
        echo "Error logging in automatically with your default ssh public key. "
        echo "Possible solutions:"
        echo " - Install the public ssh in the Fortinet device (if possible)"
        echo " - Run $0 with the -s option, to specify the ssh password. Requires sshpass installed."
        exit $return_code
    fi
fi


export SSHPASS="$sshpwd"

# Check console output setting is standard

if [[ $s_pwd_used -eq 1 ]] ; then
    original_mode=`sshpass -e ssh -p $sshport admin@$1 -T << !
    config global
show system console | grep 'output standard'
!
`
else
    original_mode=`ssh -p "$sshport" "admin@$1" show system console | grep 'output standard'`
fi

if [[ -z $original_mode ]] ; then
# If the console is not standard mode Enable continuous console output
# -T suppresses pseudo terminal warnings. &> /dev/null dumps the command output
if [[ $s_pwd_used -eq 1 ]] ; then
    sshpass -p $sshpwd ssh -p $sshport admin@$1 -T &> /dev/null << !
config system console
    set output standard
end
!
else
    ssh -p $sshport admin@$1 -T &> /dev/null << 'EOF'
    config system console
        set output standard
    end
EOF
fi
fi

if (( $# == 1)) ; then
if [[ $s_pwd_used -eq 1 ]] ; then
    sshpass -p $sshpwd ssh -p $sshport admin@$1 -T > "$1_baseline.txt" << !
show 
!
else
    ssh -p $sshport admin@$1 show > "$1_baseline.txt"
fi
fi
echo "here $#  $s_pwd_used $sshpwd $sshport $1"

if (( $# == 2)) ; then
if [[ $s_pwd_used -eq 1 ]] ; then
        coutput=`sshpass -e ssh -p $sshport admin@$1 -T << !
show
!
`
else
        coutput=$(ssh -p "$sshport" "admin@$1" 'show')
fi
echo "here2"
    running=`echo "$coutput"  | wc -l` 
    baseline=`cat "$2"  | wc -l`
    echo "Config lines in running config: $running"
    echo "Config lines in baseline $2: $baseline"

    echo "==== diff running $2 ====="
    echo ""

    diff -y -W 70 --suppress-common-lines -I "^.*set.*ENC" <(echo "$coutput") "$2" | grep -v '|'
  #  
  #echo "=== Lines only in $2 === "
  #diff --changed-group-format='%<' --unchanged-group-format='' -I "^.*set.*ENC" "$2" <(echo "$coutput")  
  #echo "=== Lines only in running === "
  #diff --changed-group-format='%>' --unchanged-group-format='' -I "^.*set.*ENC" "$2" <(echo "$coutput")  
fi

if [[ -z $original_mode ]] ; then
# If the console was not standard mode, restore it to more 
# -T suppresses pseudo terminal warnings. &> /dev/null dumps the command output
if [[ $s_pwd_used -eq 1 ]] ; then
    sshpass -p $sshpwd ssh -p $sshport admin@$1 -T &> /dev/null << !
    config system console
        set output more
    end
!
else
    ssh -p $sshport admin@$1 -T &> /dev/null << 'EOF'
    config system console
        set output more
    end
EOF
fi
fi

