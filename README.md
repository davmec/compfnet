# compfnet
Script to diff compare running configuration to previously save configuration baseline(s) in Fortinet appliances. Only FortiGate and FortiADC supported for now.

User admin assumed by default.
## Motivation
The tool is wrapping around UNIX diff commonly available in Linux distros and Mac OSX by default. 

The practicality of it relates to the capability to easily get a summary of changes with respect to a previous configuration after a "network debugging" or tuning session with FortiADC or FortiGate. The FortiADC and FortiGate configuration files can be dauntingly long and it can be hard to spot any changes that have been made (and forgotten) during a long config session. 

FortiGate already includes a similar tool in GUI, but the same is not available in FortiADC (at the moment of this writing). It can also come handy when one of the parties configuring or checking configuration only has CLI access to the platform.


## Prerequisites 
Depending on your target platform (FortiADC or FortiGate) you might need to install sshpass to automate SSH password logins.
You can find instructions to do so in the `sshpass` github repo: [https://gist.github.com/arunoda/7790979](https://gist.github.com/arunoda/7790979) 

It works with Mac OSX (brew installer):

`brew install esolitos/ipa/sshpass`



## Usage
`./compfnet.sh`

```bash
┌────────────────────────────────────────────────────────┐
│                                  ____           __     │
│      _________  ____ ___  ____  / __/___  ___  / /_    │
│     / ___/ __ \/ __ `__ \/ __ \/ /_/ __ \/ _ \/ __/    │
│    / /__/ /_/ / / / / / / /_/ / __/ / / /  __/ /_      │
│    \___/\____/_/ /_/ /_/ .___/_/ /_/ /_/\___/\__/      │
│                       /_/                              │
└────────────────────────────────────────────────────────┘

Usage: ./compfnet.sh [-p sshport] [-s sshpassword] [-m mode] [-f 'string'] fnethost [baseline-config-file]
       ./compfnet.sh fnethost
          - Fetches config from fnethost and writes it to text file fnethost_baseline.txt

       OPTIONS:
          -p sshport              Sets SSH port to other than default 22
          -s sshpassword          Sets SSH password when public key auth not available. Requires sshpass
          baseline-config-file    Fetches config from fnethost and diff compares it to baseline-config-file
          -m all                  In comparison, shows all differences side by side
          -m mod                  In comparison, shows only modified lines
          -m new                  In comparison, shows only added/removed lines(default)
          -m full                 Compare showing also common lines
          -f 'string'             Find context for config line in running config or baseline. Use single quotes.
```



## Common Uses (Examples)
Just a few examples of the intended use for the tool.

### Step 1: Generate the baseline configuration file

Running the command with only the mandatory Fortinet host (IP or hostname) generates a baseline configuration (based on the current configuration) with automatic naming to `<Platform>-<Hostname-or-IP>_baseline.txt`, where:

* `<Platform>` is the acronym of a Fortinet platform. Currently only FortiGate(FGT) and FortiADC(FAD) supported
* `<Hostname-or-IP>` is the exact transcription of the mandatory argument

When the same baseline file exists, it allows to preserve it, by saving a new baseline with an added timestamp, by answering N to this question (example for `FAD-fp2_baseline.txt`):

```
--- WARNING: Baseline file FAD-fp2_baseline.txt found. ---
Overwrite with current running config: /Yes/No/Quit (Y/N/Q)? n
```

```
# ll FAD-fp2_baseline.*
-rw-r--r--  1 dpa  staff    25K Feb 18 15:52 FAD-fp2_baseline.11-52:15-18-02-2021.txt
-rw-r--r--  1 dpa  staff    25K Feb 18 15:52 FAD-fp2_baseline.35-52:15-18-02-2021.txt
-rw-r--r--  1 dpa  staff    25K Feb 18 15:52 FAD-fp2_baseline.42-52:15-18-02-2021.txt
-rw-r--r--@ 1 dpa  staff    25K Feb 18 15:53 FAD-fp2_baseline.txt
```

The generation of the baseline file can be run with the `-p` and or `-s` options. Others are not applicable. The command produces no console output (if everything went well).

Examples:

* Option 1: Passwordless login to host 10.1.1.10, using default SSH port 22. Requires that passwordless authentication config setup is active (only available in FortiGate at the time of this writing) to accept the default SSH id for your user in the computer where you run the script.

```
compfnet.sh 10.1.1.10 
```
* Option 2: Using password based authentication instead of the default SSH rsa key of the system running the script. Currently, this is your only choice if you are using a FortiADC. SSH port set to 14050.

```
compfnet.sh -s fadpassword -p 14050 10.1.1.10 
```
Note : Password based authenticatoin requires that the tool sshpass is installed in the system (in order to automate password based logins). 

### Step 2: Do some configuration changes to your FortiGate or FortiADC via CLI or GUI


### Step 3: Run the tool again to check what was changed in the configuration

The following commands output different types of diff output to the console. The compared configurations are: **the one running in the device** and **the selected baseline file**. The file can be any configuration file, but to get the best/meaningful results is recommended to use the same platform (FortiGate or FortiADC) and the same (or closest possible) operating system version.

#### Diff side-by-side
In case you are not familiar with diff command side-by-side view, this is what it means in the context of this tool:

* `<` indicates it only exists on the left side 'running' (so it was added to running, removed from baseline).  
* `>` indicates it only exists on the right side 'running' (so it was removed in running, existed in baseline). 
* `|` indicates lines existing in both, that have been modified.

#### Passwordless
**Note:** Requires that passwordless authentication config setup is active (in the target Fortinet platform) and configured to accept the default SSH id (public key) for your user (originally stored in the computer where you run the script). 

The examples shown hereafter target a FortiGate where the user key `~/.ssh/rsa_id.pub` has been authorized and SSH service is running in TCP port 122. 

* Example 1:  Show only the lines that have been added or removed. This is the default.

```
compfnet.sh -p 122 -m new 10.1.1.10 FGT-10.1.1.10_baseline.txt
```
```
=========================================================================================
   diff                          RUNNING FGT CONFIG       < >      FGT-fp3_baseline.txt
=========================================================================================
    edit "dc_network"					                   <
        set uuid 001c2d22-7127-51eb-cc49-f7ab3302218f	   <
        set subnet 10.20.30.0 255.255.255.0		           <
    next						                           <
        set status disable				                   <
							                               >	    edit 2
							                               >	        set name "vlan100->Internet"
							                               >	        set uuid 392d8134-f68d-51ea-b00b-ca7cea090413
							                               >	        set srcintf "vlan-100"
							                               >	        set dstintf "port1"
							                               >	        set srcaddr "vlan-100 address"
							                               >	        set dstaddr "all"
							                               >	        set action accept
							                               >	        set schedule "always"
							                               >	        set service "ALL"
							                               >	        set nat enable
							                               >	    next
    edit 2						                           <
        set dst 9.9.9.9 255.255.255.255			           <
        set gateway 10.11.4.1				               <
        set device "port5"				                   <
    next						                           <
```

* Example 2:  Show only the lines that have been modified.

```
compfnet.sh -p 122 -m mod 10.1.1.10 FGT-10.1.1.10_baseline.txt
```
```
Config lines in running config:    11347
Config lines in baseline FGT-fp3_baseline.txt:    11349
=========================================================================================
   diff                          RUNNING FGT CONFIG       < >      FGT-fp3_baseline.txt
=========================================================================================
fg-hq1 # #config-version=FGVMK6-6.4.3-FW-build1778-201021:opm |	FortiGate-VM64-KVM # #config-version=FGVMK6-6.4.3-FW-build177
#conf_file_ver=6552840194967488				      			  |	#conf_file_ver=6552578201962371
    set hostname "fg-hq1"				      				  |	    set hostname "FortiGate-VM64-KVM"
        set allowaccess ping https ssh snmp http fgfm radius- |	        set allowaccess ping https ssh http fgfm
```

* Example 3:  Show both the lines added/removed and those that have been modified.

```
compfnet.sh -p 122 -m all 10.1.1.10 FGT-10.1.1.10_baseline.txt
```
```
Config lines in running config:    11347
Config lines in baseline FGT-fp3_baseline.txt:    11349
=========================================================================================
   diff                          RUNNING FGT CONFIG       < >      FGT-fp3_baseline.txt
=========================================================================================
fg-hq1 # #config-version=FGVMK6-6.4.3-FW-build1778-201021:opm  | FortiGate-VM64-KVM # #config-version=FGVMK6-6.4.3-FW-build177
#conf_file_ver=6552840194967488				      			   | #conf_file_ver=6552578201962371
    set hostname "fg-hq1"				      				   |     set hostname "FortiGate-VM64-KVM"
        set allowaccess ping https ssh snmp http fgfm radius-  |         set allowaccess ping https ssh http fgfm


        edit "dc_network"					                   <
            set uuid 001c2d22-7127-51eb-cc49-f7ab3302218f	   <
            set subnet 10.20.30.0 255.255.255.0		           <
        next						                           <
            set status disable				                   <
    							                               >	 edit 2
    							                               >	     set name "vlan100->Internet"
    							                               >	     set uuid 392d8134-f68d-51ea-b00b-ca7cea090413
    							                               >	     set srcintf "vlan-100"
    							                               >	     set dstintf "port1"
    							                               >	     set srcaddr "vlan-100 address"
    							                               >	     set dstaddr "all"
    							                               >	     set action accept
    							                               >	     set schedule "always"
    							                               >	     set service "ALL"
    							                               >	     set nat enable
    							                               >	 next
        edit 2						                           <
            set dst 9.9.9.9 255.255.255.255			           <
            set gateway 10.11.4.1				               <
            set device "port5"				                   <
        next						                           <
fg-hq1 # 						                               / FortiGate-VM64-KVM #
```


* Example 4:  Show everything, including lines that are the same in both the running config and the baseline file.

```
compfnet.sh -p 122 -m full 10.1.1.10 FGT-10.1.1.10_baseline.txt
```
```

Config lines in running config:    11347
Config lines in baseline FGT-fp3_baseline.txt:    11349
=========================================================================================
   diff                          RUNNING FGT CONFIG       < >      FGT-fp3_baseline.txt
=========================================================================================
fg-hq1 # #config-version=FGVMK6-6.4.3-FW-build1778-201021:opm | FortiGate-VM64-KVM # #config-version=FGVMK6-6.4.3-FW-build177
#conf_file_ver=6552840194967488                               | #conf_file_ver=6552578201962371
#buildno=1778                                                   #buildno=1778
#global_vdom=1                                                  #global_vdom=1
config system global                                            config system global
    set admintimeout 480                                            set admintimeout 480
    set alias "FortiGate-VM64-KVM"                                  set alias "FortiGate-VM64-KVM"
    set hostname "fg-hq1"                                     |     set hostname "FortiGate-VM64-KVM"
    set switch-controller enable                                    set switch-controller enable
    set timezone 04                                                 set timezone 04
end                                                             end
config system accprofile                                        config system accprofile
    edit "prof_admin"                                               edit "prof_admin"
        set secfabgrp read-write                                        set secfabgrp read-write
        set ftviewgrp read-write                                        set ftviewgrp read-write
        set authgrp read-write                                          set authgrp read-write
        set sysgrp read-write                                           set sysgrp read-write
        set netgrp read-write                                           set netgrp read-write
        set loggrp read-write                                           set loggrp read-write
        set fwgrp read-write                                            set fwgrp read-write
        set vpngrp read-write                                           set vpngrp read-write
.
.
.
(continues till end of the configuration)
```
	
You will probably want to pipe the output of this last option into more ( `| more` ) to go through it.
	
#### Password based aunthentication

**Note:** Password based authenticatoin requires that the tool sshpass is installed in the system (in order to automate password based logins).

The examples shown in this section target a FortiADC with SSH admin password fortiadcpwd. SSH is running in the default port 22. FortiADC management IP (10.0.2.10) has been mapped in /etc/hosts to adc1. IP address can also be used instead of hostname, as in the previous section examples.


* Example 1:  Show only the lines that have been added or removed. This is the default.

```
compfnet.sh -s fortiadcpwd -m new adc1 FAD-adc1_baseline.txt
```
```
Config lines in running config:     1080
Config lines in baseline FAD-fp2_baseline.txt:     1083
=========================================================================================
   diff                          RUNNING FAD CONFIG       < >      FAD-fp2_baseline.txt
=========================================================================================							                                >	  edit 3
							                                >	    set interface port3
							                                >	    set port 443
							                                >	    set max-packet-count 300
							                                >	  next
							                                >	  edit "test"
							                                >	    set real-server-ssl-profile NONE
							                                >	    config  pool_member
							                                >	    end
							                                >	  next
  edit "empty_pool"					                        <
    set health-check-ctrl enable			                <
    set health-check-list LB_HLTHCK_ICMP 		            <
    set real-server-ssl-profile NONE			            <
    config  pool_member					                    <
    end							                            <
  next							                            <
FortiADC-KVM # 						      /	FortiADC-KVM #
```

* Example 2:  Show only the lines that have been modified.

```
compfnet.sh -s fortiadcpwd -m mod adc1 FAD-adc1_baseline.txt
```
```
Config lines in running config:     1080
Config lines in baseline FAD-fp2_baseline.txt:     1083
=========================================================================================
   diff                          RUNNING FAD CONFIG       < >      FAD-fp2_baseline.txt
=========================================================================================
    set allowaccess https ping ssh http 		            |	    set allowaccess https ping http
    set allowaccess ping snmp 				                |	    set allowaccess ping
```

* Example 3:  Show both the lines added/removed and those that have been modified.

```
compfnet.sh -s fortiadcpwd -m all adc1 FAD-adc1_baseline.txt
```

```
Config lines in running config:     1080
Config lines in baseline FAD-fp2_baseline.txt:     1083
=========================================================================================
   diff                          RUNNING FAD CONFIG       < >      FAD-fp2_baseline.txt
=========================================================================================
    set allowaccess https ping ssh http 		            |	    set allowaccess https ping http
    set allowaccess ping snmp 				                |	    set allowaccess ping
							                                >	  edit 3
							                                >	    set interface port3
							                                >	    set port 443
							                                >	    set max-packet-count 300
							                                >	  next
							                                >	  edit "test"
							                                >	    set real-server-ssl-profile NONE
							                                >	    config  pool_member
							                                >	    end
							                                >	  next
  edit "empty_pool"					                        <
    set health-check-ctrl enable			                <
    set health-check-list LB_HLTHCK_ICMP 		            <
    set real-server-ssl-profile NONE			            <
    config  pool_member					                    <
    end							                            <
  next							                            <
FortiADC-KVM # 						      /	FortiADC-KVM #
```


* Example 4:  Show everything, including lines that are the same in both the running config and the baseline file.

```
compfnet.sh -s fortiadcpwd -m full adc1 FAD-adc1_baseline.txt
```

```
Config lines in running config:     1080
Config lines in baseline FAD-fp2_baseline.txt:     1083
=========================================================================================
   diff                          RUNNING FAD CONFIG       < >      FAD-fp2_baseline.txt
=========================================================================================
FortiADC-KVM # config system global                             FortiADC-KVM # config system global
  set hostname FortiADC-KVM                                       set hostname FortiADC-KVM
end                                                             end
config system traffic-group                                     config system traffic-group
end                                                             end
config system interface                                         config system interface
  edit "port1"                                                    edit "port1"
    set vdom root                                                   set vdom root
    set ip 10.9.8.2/24                                              set ip 10.9.8.2/24
    set allowaccess https ping ssh http telnet                      set allowaccess https ping ssh http telnet
    config  ha-node-ip-list                                         config  ha-node-ip-list
    end                                                             end
  next                                                            next
  edit "port2"                                                    edit "port2"
    set vdom root                                                   set vdom root
    set ip 10.11.12.1/24                                            set ip 10.11.12.1/24
    set allowaccess https ping ssh http                       |     set allowaccess https ping http
    config  ha-node-ip-list                                         config  ha-node-ip-list
    end                                                             end
.
.
.
(continues till end of the configuration)
```

* Example 5:  Show both the lines added/removed and those that have been modified. Now using a custom SSH port. Especially useful if you target port forwarded hosts, like FortiADC in FortiPoC.

```
compfnet.sh -s fortiadcpwd -p 10103 -m all adc1 FAD-adc1_baseline.txt
```
Similar output to example 3.

## Locating configuration changes in context
The previous command options will show differences, but those are usually single lines, potentially scattered in the configuration file. If you do not know the context for a particular difference (added/removed or modified line), you can run again the tool as follows: `compfnet.sh -f 'config line can have spaces' adc [baseline]` .  

The idea would be using the lines that were found added, removed or modified (as per previous section commands).

The tool will then display the Fortinet configuration context (or contexts if it appears in serveral places) containing the searched line. This option can be run against the running configuration or the baseline configuration file (depending on where you are expecting to find the corresponding line).

If you run the `-m new`, `-m mod` or `-m all` comparisons, the running config will be displayed in the left and the baseline on the right. This way you can know where to search for the line (added or modified).  Reminder:

* `<` indicates it only exists on the left side 'running' (so it was added to running, removed from baseline).  
* `>` indicates it only exists on the right side 'running' (so it was removed in running, existed in baseline). 
* `|` indicates lines existing in both, that have been modified.

### Searching for context in running config line change

Let us try get context for the found "modified" line from Example 2 or 3 in the previous section `set allowaccess https ping ssh http`

```
compfnet.sh -s fortiadcpwd -p 10103 -f 'set allowaccess https ping ssh http' adc1 
```
```
---- Searching RUNNING CONFIG for 'set allowaccess https ping ssh http' ----

config system interface
  edit "port1"
    set vdom root
    set ip 10.9.8.2/24
    set allowaccess https ping ssh http telnet
    config  ha-node-ip-list
    end
```


### Searching for context in baseline config line change
Let us search now for something that was deleted from the baseline file (according to previous section) like `max-packet-count 300`


```
compfnet.sh -s fortiadcpwd -p 10103 -f 'max-packet-count 'adc1 
```
```
---- Searching RUNNING CONFIG for 'max-packet-count 300' ----

config system tcpdump
  edit 2
    set interface port1
    set host 10.11.12.0/24
    set port 80
    set max-packet-count 4000
  next
  edit 3
    set interface port3
    set port 443
    set max-packet-count 300
  next
  edit 4
    set interface port1
    set host 10.9.8.0/24
    set port 80
    set max-packet-count 200
  next
  edit 1
    set interface port1
    set host 10.9.8.0/24
    set max-packet-count 300
  next
end
```


### Tips and other ways to see config context

* If the output of the previous context commands is still too long it might overrun your terminal scrolling capacity or simply make you miss something.  You can fix that by piping the output of the command into more. Example:

```
 compfnet.sh -f 'security' fgt-hq | more
```
```
        set security-mode captive-portal
        set device-identification enable
        set snmp-index 10
        set switch-controller-access-vlan enable
        set switch-controller-feature nac
        set interface "fortilink"
        set vlanid 4089
    next
    edit "vlan666"
        set vdom "root"
        set ip 10.6.66.254 255.255.255.0
        set device-identification enable
        set role lan
        set snmp-index 11
        set interface "fortilink"
        set vlanid 666
    next
    edit "vlan-100"
        set vdom "root"
        set ip 10.100.0.254 255.255.255.0
        set allowaccess ping https ssh http
        set device-identification enable
        set role lan
        set snmp-index 12
        set interface "fortilink"
        set vlanid 100
    next
end
config system email-server
    set server "notification.fortinet.net"
    set port 465
    set security smtps
end
config switch-controller security-policy 802-1X
    edit "802-1X-policy-default"
        set user-group "SSO_Guest_Users"
        set mac-auth-bypass disable
        set open-auth disable
        set eap-passthru enable
        set eap-auto-untagged-vlans enable
        set guest-vlan disable
        set auth-fail-vlan disable
        set framevid-apply enable
        set radius-timeout-overwrite disable
        set authserver-timeout-vlan disable
    next
end
config switch-controller security-policy local-access
    edit "default"
        set mgmt-allowaccess https ping ssh
        set internal-allowaccess https ping ssh
    next
:    
```

* If the context filtering skipped something you want to see, or you want to check the context for both running and baseline side-by-side, you can pipe the command comparison (with `-m full` option) into `grep` with `-A n` (after match), `-B n` (before match) or `-C n` (after and before) options (with `n` the number of context lines to display). A simple regular expression can include the characters used to indicate insertion/deletion/modification ( < > | ) to go to those interesting lines.

 Usually the match(es) is(are) highlighted in colour and the `--` in the output indicates that there are lines not displayed between matches.  
 
 The sample here tries to find about that lonely 'set status disable' found in Passwordless examples.

```
 compfnet.sh -p 122 -m full 10.1.1.10 FGT-10.1.1.10_baseline.txt | grep -C 10 'set status disable.*<'
```
```
            config max-range-segment				            config max-range-segment
                set status enable				                        set status enable
                set log enable					                        set log enable
                set severity high				                        set severity high
            end							                                end
        end							                                end
    next							                            next
end								                            end
config firewall policy						                config firewall policy
    edit 1							                            edit 1
        set status disable				                 <
        set name "vlan666 to internet"				        set name "vlan666 to internet"
        set uuid 2ce20830-f680-51ea-a7b3-cd0525540db3	    set uuid 2ce20830-f680-51ea-a7b3-cd0525540db3
        set srcintf "vlan666"					            set srcintf "vlan666"
        set dstintf "port1"					                set dstintf "port1"
        set srcaddr "vlan666 address"				        set srcaddr "vlan666 address"
        set dstaddr "all"					                set dstaddr "all"
        set action accept					                set action accept
        set schedule "always"					            set schedule "always"
        set service "ALL"					                set service "ALL"
        set nat enable						                set nat enable
```
