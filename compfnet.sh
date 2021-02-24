#!/bin/bash
#
# Simple tool to generate/display diff of  CLI configurations for FortiADC and FortiGate
#
# Disclaimer: This tool comes without warranty of any kind.
#             Use it at your own risk. We assume no liability for the accuracy,, group-management
#             correctness, completeness, or usefulness of any information
#             provided nor for any sort of damages using this tool may cause.

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
        echo "Usage: $0 [-p sshport] [-s sshpassword] [-m mode] [-f 'string'] fnethost [baseline-config-file]"
        echo "       $0 fnethost"
        echo "          - Fetches config from fnethost and writes it to text file fnethost_baseline.txt"
        echo ""            
        echo "       OPTIONS:"
        echo "          -p sshport              Sets SSH port to other than default 22"
        echo "          -s sshpassword          Sets SSH password when public key auth not available. Requires sshpass"
        echo "          baseline-config-file    Fetches config from fnethost and diff compares it to baseline-config-file"
        echo "          -m all                  In comparison, shows all differences side by side"
        echo "          -m mod                  In comparison, shows only modified lines"
        echo "          -m new                  In comparison, shows only added/removed lines(default)"
        echo "          -m full                 Compare showing also common lines"
        echo "          -f 'string'             Find context for config line in running config or baseline. Use single quotes."
        exit 1
}

# Variable and parameter initialization
# Default SSH port unless specified in option
sshport=22
s_pwd_used=0
show_mode="new"
mode=""
find_flag=0
find_string=""

function getPlatform
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
    #echo "debug sn $sn_line"
    platform=$( echo $sn_line | sed -e 's:.*FAD.*:FAD:' -e 's:.*FG.*:FGT:')
    echo "$platform"
}

function printContext
{
    # Prints full config-end context for indicated line
    # In running config or file (when second arg supplied and valid file)    
    local conf_line=$find_string
    local running_conf=""
    local file=""

    if [[ $fPlatform == "FGT" ]] ; then
    #    echo "-f option not supported in this platform: $fPlatform"
    #    exit 1
    sed_args="/^config/{
:a
N
/end/\!ba
/$conf_line/p
}"
    else
    #preparing sed arguments with searched conf_line
    sed_args="/config|edit/{
:a
N
/end/\!ba
/$conf_line/p
}"
    fi

    sed_args=$(sed 's/\\!/!/g' <<< "$sed_args")

 # echo "$sed_args"

    if (( $# == 0)) ; then
    # if the file argument was not provided or does not exist, go for running
        if [[ $s_pwd_used -eq 1 ]] ; then
            running=$(sshpass -e ssh -p $sshport admin@$fnhost -T << !
show
!
)
        else
            running=$(ssh -p "$sshport" "admin@$fnhost" 'show')
        fi
        # sed has to scan data from variable instead of file in this case
        # Searsching for 
        echo "---- Searching RUNNING CONFIG for '$conf_line' ----"
        echo ""
        sed -nE "$sed_args" <<< "$running"
#        sed 's/\$$//g' <<< "$result"
    elif (( $# == 1)) ; then
        file=$1
        echo "---- Searching FILE $file for '$conf_line' ----"
        echo ""
        sed -nE "$sed_args" $file
 #       sed 's/\$$//g' <<< "$result"
    else
        echo "Wrong number of arguments passed to $0. It takes one or zero."
        exit 1
    fi
}

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

while getopts "h?p:s:m:f:" opt; do
    case "$opt" in
    h|\?)
        usage
        ;;
    f)  find_flag=1
        find_string=$OPTARG
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
    else
        sshpass -e ssh -p $sshport admin@$1 exit &> /dev/null
        return_code=$?
        if [[ $return_code -eq 6 ]] ; then
            echo "Error unknown Host Public Key for $1"
            echo "Possible solution:"
            echo " - Log in manually with SSH once to add the host key to your known_hosts file"
            exit $return_code
        fi
    fi
else
    # Check that the user default user key has been added to target host. 
    ssh -p $sshport -q -o "BatchMode=yes" admin@$1 exit &> /dev/null
    return_code=$?
    if [[ $return_code -ne 0 ]] ; then
        echo "Error logging in automatically with your default ssh public key. "
        echo "Possible solutions:"
        echo " - Install the public ssh in the Fortinet device (if possible)"
        echo " - Log in manually with SSH once to add the host key to your known_hosts file"
        echo " - Run $0 with the -s option, to specify the ssh password. Requires sshpass installed."
        exit $return_code
    fi
fi

fPlatform=`getPlatform $1`

# Check console output setting is standard - The command works the same in FortiADC and FortiGate
# config global command will fail in non VDOM modes, but it is needed for those
# Standard Error sent to null device to avoid displaying that error message

    if [[ $s_pwd_used -eq 1 ]] ; then
        mode=`sshpass -e ssh -p $sshport admin@$1 -T 2> /dev/null << 'EOF'
        config global
        show system console 
EOF
`
    else
        mode=`ssh -p $sshport admin@$1 -T 2> /dev/null << 'EOF'
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

if (( $# == 1)) ; then
    if [[ $find_flag -eq 1 ]] ; then
        # saving the fortinet host before calling printContext
        fnhost=$1
        printContext 
        # exit after this since we do not want to rewrite the baseline for this
        exit 0
    fi

    base_file_name="$fPlatform-$1_baseline"

    # check if file exists to prevent overwriting
    if [[ -f "$base_file_name.txt" ]] ; then
        echo "--- WARNING: Baseline file $base_file_name.txt found. ---"
        read -p "Overwrite with current running config: /Yes/No/Quit (Y/N/Q)? " resp
        case $resp in
            [Yy]* )  base_file_name="$base_file_name.txt" ;;
            [Nn]* )  timestamp=`date +%S-%M:%H-%d-%m-%Y`; base_file_name="$base_file_name.$timestamp.txt" ;
                     echo "RUNNING config saved to file(suffix format SEC-MIN:HOUR-Day-Month-Year):  $base_file_name" ;;
            * )  echo "Quiting without file changes" ; exit 1 ;;
        esac
    else
        base_file_name="$base_file_name.txt"
    fi 

    if [[ $s_pwd_used -eq 1 ]] ; then
        sshpass -p $sshpwd ssh -p $sshport admin@$1 -T > $base_file_name << !
show
!
    else
        ssh -p $sshport admin@$1 show > $base_file_name
    fi
fi

if (( $# == 2)) ; then
    if [[ $find_flag -eq 1 ]] ; then
        # saving the fortinet host before calling printContext
        fnhost=$1
        printContext $2
        # exit after this since we do not want to go through diff compare for this
        exit 0
    fi    
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

fi


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
