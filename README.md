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

Usage: ./compfnet.sh [-p sshport] [-s sshpassword] [-m mode] fnethost [baseline-config-file]
       ./compfnet.sh fnethost
          - Fetches config from fnethost and writes it to text file fnethost_baseline.txt

       OPTIONS:
          -p sshport              Sets SSH port to something different than the default number 22
          -s sshpassword          Sets SSH password when public key auth not available. Requires sshpass.
          baseline-config-file    Fetches config from fnethost and diif compares it to config file baseline-config-file
          -m all                  In comparison, shows all differences side by side
          -m mod                  In comparison, shows only modified lines
          -m new                  In comparison, shows only added/removed lines(default)
          -m full                 Compare showing also common lines
```



## Common Uses (Examples)
Just a few examples of the intended use for the tool.

### Step 1: Generate the baseline configuration file 

* Option 1: Passwordless login to host 10.1.1.10, using default SSH port 22. Requires that passwordless authentication config setup is active (only available in FortiGate at the time of this writing) to accept the default SSH id for your user in the computer where you run the script.

```
compfnet.sh 10.1.1.10 
```
* Option 2: Using password based authentication instead of the default SSH rsa key of the system running the script. This is your only choice if you are using a FortiADC.

```
compfnet.sh -s fgtpassword 10.1.1.10 
```
Note : Password based authenticatoin requires that the tool sshpass is installed in the system (in order to automate password based logins). 

### Step 2: Do some configuration changes to your FortiGate or FortiADC via CLI or GUI


### Step 3: Run the tool again to check what was changed in the configuration

#### Passwordless
**Note:** Requires that passwordless authentication config setup is active and configured to accept the default SSH id for your user in the computer where you run the script. 

The examples shown hereafter target a FortiGate where the user key ~/.ssh/rsa_id.pub has been authorized and SSH service is running in TCP port 122. 

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

The examples shown in this section target a FortiADC with SSH admin password fortiadcpwd. SSH is running in the default port 22. FortiADC management IP (10.0.2.10) has been mapped in /etc/hosts to adc1.


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


