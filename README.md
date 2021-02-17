# compfnet
Script to diff compare running configuration to previously save configuration baseline(s) in Fortinet appliances. Only FortiGate and FortiADC supported for now.

User admin assumed by default.
## Motivation
The tool is wrapping around UNIX diff commonly available in Linux distros and Mac OSX by default. 

The practicality of it relates to the capability to easily get a summary of changes with respect to a previous configuration after a "network debugging" or tuning session with FortiADC or FortiGate. The FortiADC and FortiGate configuration files can be dauntingly long and it can be hard to spot any changes that have been made (and forgotten) during a long config session. 

FortiGate already includes a similar tool in GUI, but the same is not available in FortiADC (at the moment of this writing). It can also come handy when one of the parties configuring or checking configuration only has CLI access to the platform.


## Prerequisites 
Depending on your target platform (FortiADC or FortiGate) you might need to install sshpass to automate SSH password logins.
You can find instructions to do so in the sshpass github repo: [https://gist.github.com/arunoda/7790979](https://gist.github.com/arunoda/7790979) 

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

* <Platform> is the acronym of a Fortinet platform. Currently only FortiGate(FGT) and FortiADC(FAD) supported
* <Hostname-or-IP> is the exact transcription of the mandatory argument

The generation of the baseline file can be run with the `-p` and or `-s` options. Others are not applicable.

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

#### Passwordless
**Note:** Requires that passwordless authentication config setup is active (in the target Fortinet platform) and configured to accept the default SSH id (public key) for your user (originally stored in the computer where you run the script). 

The examples shown hereafter target a FortiGate where the user key `~/.ssh/rsa_id.pub` has been authorized and SSH service is running in TCP port 122. 

* Example 1:  Show only the lines that have been added or removed. This is the default.

```
compfnet.sh -p 122 -m new 10.1.1.10 FGT-10.1.1.10_baseline.txt
```

* Example 2:  Show only the lines that have been modified.

```
compfnet.sh -p 122 -m mod 10.1.1.10 FGT-10.1.1.10_baseline.txt
```

* Example 3:  Show both the lines added/removed and those that have been modified.

```
compfnet.sh -p 122 -m all 10.1.1.10 FGT-10.1.1.10_baseline.txt
```

* Example 4:  Show everything, including lines that are the same in both the running config and the baseline file.

```
compfnet.sh -p 122 -m full 10.1.1.10 FGT-10.1.1.10_baseline.txt
```


#### Password based aunthentication

**Note:** Password based authenticatoin requires that the tool sshpass is installed in the system (in order to automate password based logins).

The examples shown in this section target a FortiADC with SSH admin password fortiadcpwd. SSH is running in the default port 22. FortiADC management IP (10.0.2.10) has been mapped in /etc/hosts to adc1. IP address can also be used instead of hostname, as in the previous section examples.


* Example 1:  Show only the lines that have been added or removed. This is the default.

```
compfnet.sh -s fortiadcpwd -m new adc1 FAD-adc1_baseline.txt
```

* Example 2:  Show only the lines that have been modified.

```
compfnet.sh -s fortiadcpwd -m mod adc1 FAD-adc1_baseline.txt
```

* Example 3:  Show both the lines added/removed and those that have been modified.

```
compfnet.sh -s fortiadcpwd -m all adc1 FAD-adc1_baseline.txt
```

* Example 4:  Show everything, including lines that are the same in both the running config and the baseline file.

```
compfnet.sh -s fortiadcpwd -m full adc1 FAD-adc1_baseline.txt
```

* Example 5:  Show both the lines added/removed and those that have been modified. Now using a custom SSH port. Especially useful if you target port forwarded hosts, like FortiADC in FortiPoC.

```
compfnet.sh -s fortiadcpwd -p 10103 -m all adc1 FAD-adc1_baseline.txt
```


## Locating configuration changes in context
The previous command options will show differences, but those are usually single lines, potentially scattered in the configuration file. If you do not know the context for a particular difference (added/removed or modified line), you can run again the tool as follows: `compfnet.sh -f 'config_line can have spaces' adc [baseline]` . 

The tool will then display the Fortinet configuration context (or contexts if it appears in serveral places) containing the searched line. This option can be run against the running configuration or the baseline configuration file (depending on where you are expecting to find the corresponding line).

If you run the `-m new`, `-m mod` or `-m all` comparisons, the running config will be displayed in the left and the baseline on the right. This way you can know where to search for the line (added or modified). 

* `<` indicates it only exists on the left side 'running' (so it was added to running, removed from baseline).  
* `>` indicates it only exists on the right side 'running' (so it was removed in running, existed in baseline). 
* `|` indicates lines existing in both, that have been modified.

### Searching for context in running config line change

```
compfnet.sh -s fortiadcpwd -p 10103 -m all -f adc1 
```


### Searching for context in baseline config line change

```
compfnet.sh -s fortiadcpwd -p 10103 -m all -f adc1 
```

### Tips and other ways to see config context

* If the output of the previous context commands is still too long it might overrun your terminal scrolling capacity or simply make you miss something.  You can fix that by piping the output of the command into more. Example:

```
 compfnet.sh -f 'security' fgt-hq | more
```
* If the context filtering skipped something you want to see, or you want to check the context for both running and baseline side-by-side, you can pipe the command comparison (with `-m full` option) into `grep` with `-A n` (after match), `-B n` (before match) or `-C n` (after and before) options (with `n` the number of context lines to display). Usually the match(es) is(are) highlighted in colour and the `--` in the output indicates that there are lines not displayed between matches.  

```
 compfnet.sh fgt-hq -m full | grep -C 2 dns
```

