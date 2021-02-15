#!/bin/bash
#
# Simple tool to generate/display diff of  CLI configurations for FortiADC and FortiGate
#


function usage {
        echo '┌────────────────────────────────────────────────────────┐'
        echo '│                                  ____           __     │'
        echo '│      _________  ____ ___  ____  / __/___  ___  / /_    │'
        echo '│     / ___/ __ \/ __ `__ \/ __ \/ /_/ __ \/ _ \/ __/    │'
        echo '│    / /__/ /_/ / / / / / / /_/ / __/ / / /  __/ /_      │'
        echo '│    \___/\____/_/ /_/ /_/ .___/_/ /_/ /_/\___/\__/      │'
        echo '│                       /_/                              │'
        echo '└────────────────────────────────────────────────────────┘'
        echo ""
        echo "Usage: $0 [-p sshport] [-s sshpassword] [-m mode] fnethost [baseline-config-file]"
        echo "       $0 fnethost"
        echo "          - Fetches config from fnethost and writes it to text file fnethost_baseline.txt"
        echo ""            
        echo "       OPTIONS:"
        echo "          -p sshport              Sets SSH port to something different than the default number 22"
        echo "          -s sshpassword          Sets SSH password when public key auth not available. Requires sshpass."
        echo "          baseline-config-file    Fetches config from fnethost and diif compares it to config file baseline-config-file"
        echo "          -m all                  In comparison, shows all differences side by side"
        echo "          -m mod                  In comparison, shows only modified lines"
        echo "          -m new                  In comparison, shows only added/removed lines(default)"
        echo "          -m full                 Compare showing also common lines"
        exit 1
}

# Variable and parameter initialization
# Default SSH port unless specified in option
sshport=22
s_pwd_used=0
show_mode="new"
mode=""

function getPlatform()
{
    local platform="Unsupported"
    local sn_line=""
if [[ $s_pwd_used -eq 1 ]] ; then
        sn_line=`sshpass -e ssh -p $sshport admin@$1 -T << !
            get system status
!
`
        sn_line=`echo "$sn_line" | grep 'Serial-Number'`
else
        sn_line=`ssh -p "$sshport" "admin@$1" get system status | grep 'Serial-Number'`
fi
#    echo "debug sn $sn_line"
    platform=$( echo $sn_line | sed -e 's:.*FAD.*:FAD:' -e 's:.*FGT.*:FGT:')
    echo "$platform"
}


# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

while getopts "h?p:s:m:" opt; do
    case "$opt" in
    h|\?)
        usage
        ;;
    p)  sshport=$OPTARG
        ;;
    s)  sshpwd=$OPTARG
        s_pwd_used=1
        ;;
    m)  show_mode=$OPTARG
        ;;
    :)  echo "Invalid option: -$OPTARG requires an argument" 1>&2
        exit 0
        ;;
    *)  echo "Unimplemented option: -$OPTARG" >&2; exit 1;;
    esac    
done

shift $((OPTIND-1))

#echo "Debug: first $1 second $2 port $sshport pwd $sshpwd"

# validate input parameters
export SSHPASS="$sshpwd"

# check number of args (non-options): $#
if [[ $# > 2 ]] || [[ $# < 1 ]] ; then
    usage
    exit 1
elif [[ $# -eq 2 ]] && [[ ! -f $2 ]] ; then
    echo "File $2 does not exist"
    exit 1
fi

if [[ $sshport < 1 ]] || [[ $sshport > 65535 ]] ; then
    echo "Invalid SSH port chosen: $sshport. Valid range: 1-65535"
    exit 1
fi

if [[ $show_mode != "new" ]] && [[ $show_mode != "mod" ]] && [[ $show_mode != "all" ]] && [[ $show_mode != "full" ]]; then
    echo "Invalid value for m opion"
    usage
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
    ssh -p $sshport -q -o "BatchMode=yes" admin@$1 exit 0
    return_code=$?
#    echo "return code = $return_code"
    if [[ $return_code -ne 0 ]] ; then
        echo "Error logging in automatically with your default ssh public key. "
        echo "Possible solutions:"
        echo " - Install the public ssh in the Fortinet device (if possible)"
        echo " - Run $0 with the -s option, to specify the ssh password. Requires sshpass installed."
        exit $return_code
    fi
fi

fPlatform=`getPlatform $1`

# Check console output setting is standard
if [[ $fPlatform == "FGT" ]] 
    then
    if [[ $s_pwd_used -eq 1 ]] ; then
        mode=`sshpass -e ssh -p $sshport admin@$1 -T << !
    show system console 
!
`
    else
        mode=`ssh -p "$sshport" "admin@$1" show system console`
    fi
    
    original_mode=$(echo "$mode" | grep 'standard')
    
    if [[ -z $original_mode ]] ; then
    # If the console is not standard mode Enable continuous console output
    # -T suppresses pseudo terminal warnings. &> /dev/null dumps the command output
        if [[ $s_pwd_used -eq 1 ]] ; then
            sshpass -p $sshpwd ssh -p $sshport admin@$1 -T &> /dev/null << 'EOF'
            config system console
                set output standard
            end
EOF
        else
            ssh -p $sshport admin@$1 -T &> /dev/null << 'EOF'
            config system console
                set output standard
            end
EOF
        fi
    fi
elif [[ $fPlatform == "FAD" ]]
then
    if [[ $s_pwd_used -eq 1 ]] ; then
        mode=`sshpass -e ssh -p $sshport admin@$1 -T << 'EOF'
        config global
        show system console 
EOF
`
    else
        mode=`ssh -p $sshport admin@$1 -T << 'EOF'
        config global
        show system console 
EOF
`
    fi

    original_mode=` echo "$mode" | grep 'standard' `

    if [[ -z $original_mode ]] ; then
    # If the console is not standard mode Enable continuous console output
    # -T suppresses pseudo terminal warnings. &> /dev/null dumps the command output
        if [[ $s_pwd_used -eq 1 ]] ; then
            sshpass -e ssh -p $sshport admin@$1 -T &> /dev/null << 'EOF'
            config global
            config system console
                set output standard
            end
            end
EOF
        else
            ssh -p $sshport admin@$1 -T &> /dev/null << 'EOF'
            config global
            config system console
                set output standard
            end
            end
EOF
        fi
    fi
else
    echo "$fPlatform"
    exit 1
fi

if (( $# == 1)) ; then
    if [[ $s_pwd_used -eq 1 ]] ; then
        sshpass -p $sshpwd ssh -p $sshport admin@$1 -T > "$fPlatform-$1_baseline.txt" << !
show
!
    else
        ssh -p $sshport admin@$1 show > "$fPlatform-$1_baseline.txt"
    fi
fi
#echo "here $#  $s_pwd_used $sshpwd $sshport $1"

if (( $# == 2)) ; then
    if [[ $s_pwd_used -eq 1 ]] ; then
        coutput=`sshpass -e ssh -p $sshport admin@$1 -T << !
    show
!
`
    else
        coutput=$(ssh -p "$sshport" "admin@$1" 'show')
    fi
    running=`echo "$coutput"  | wc -l` 
    baseline=`printf '%b\n' "$(cat $2)"| wc -l`
    echo "Config lines in running config: $running"
    echo "Config lines in baseline $2: $baseline"
    echo "========================================================================================="
    echo "   diff                          RUNNING $fPlatform CONFIG       < >      $2       "
    echo "========================================================================================="

    if [[ $show_mode == "new" ]]
    then
        diff -y --suppress-common-lines -I "^.*set.*pass.*ENC" <(echo "$coutput") "$2" | grep -E -i '<|>'
    elif [[ $show_mode == "mod" ]]
    then
        diff -y --suppress-common-lines -I "^.*set.*pass.*ENC" <(echo "$coutput") "$2" | grep '|'
    elif [[ $show_mode == "all" ]]
    then
        diff -y --suppress-common-lines -I "^.*set.*pass.*ENC" <(echo "$coutput") "$2" 
    else
        diff -y <(echo "$coutput") "$2" 
    fi

  #  
  #echo "=== Lines only in $2 === "
  #diff --changed-group-format='%<' --unchanged-group-format='' -I "^.*set.*ENC" "$2" <(echo "$coutput")  
  #echo "=== Lines only in running === "
  #diff --changed-group-format='%>' --unchanged-group-format='' -I "^.*set.*ENC" "$2" <(echo "$coutput")  
fi

if [[ $fPlatform == "FGT" ]] 
then
    if [[ -z $original_mode ]] ; then
    # If the console was not standard mode, restore it to more 
# If the console was not standard mode, restore it to more 
    # If the console was not standard mode, restore it to more 
# If the console was not standard mode, restore it to more 
    # If the console was not standard mode, restore it to more 
    # -T suppresses pseudo terminal warnings. &> /dev/null dumps the command output
        if [[ $s_pwd_used -eq 1 ]] ; then
            sshpass -e ssh -p $sshport admin@$1 -T &> /dev/null << 'EOF'
            config system console
                set output more
            end
EOF
        else
            ssh -p $sshport admin@$1 -T &> /dev/null << 'EOF'
            config system console
                set output more
            end
EOF
        fi
    fi
elif [[ $fPlatform == "FAD" ]]
then
    if [[ -z $original_mode ]] ; then
    # If the console was not standard mode, restore it to more 
    # -T suppresses pseudo terminal warnings. &> /dev/null dumps the command output
    if [[ $s_pwd_used -eq 1 ]] ; then
        sshpass -e ssh -p $sshport admin@$1 -T &> /dev/null << 'EOF'
        config global
        config system console
            set output more
        end
        end
EOF
    else
        ssh -p $sshport admin@$1 -T &> /dev/null << 'EOF'
        config global
        config system console
            set output more
        end
        end
EOF
    fi
    fi
else
    echo "$fPlatform"
    exit 1
fi