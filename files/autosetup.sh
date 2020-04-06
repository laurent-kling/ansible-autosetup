#!/bin/bash

helpFunction()
{
   echo ""
   echo "Automatic creation of Ansible environment with Vault linked to Mac Keychain"
   echo "Usage: $0 -n name [-p path] [-y]"
   echo -e "\t-n name of the project"
   echo -e "\t-p path [current path of the script]"
   echo -e "\t-y [confirm all parameters are OK]"
   exit 1 # Exit script after printing help
}

function fail () {
    printf '%s\n' "$1" # >&2  ## Send message to stderr. Exclude >&2 if you don't want it that way.
    exit "${2-1}"  ## Return a code specified by $2 or 1 by default.
}

while getopts "n:p:y" opt
do
   case "$opt" in
      n ) project="$OPTARG" ;;
      p ) chemin="$OPTARG" ;;
      y ) autoconfirm="yes" ;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

#echo "$project"
#echo "$chemin"
#echo "$autoconfirm"

current="`pwd`"
#check the empty path case = current path
if [ -z "$chemin" ]
then
  chemin=$current
fi

# Print helpFunction in case parameters are empty
if [ -z "$project" ] || [ -z "$chemin" ]
then
   echo "Some or all of the parameters are empty";
   helpFunction
fi

# Begin script in case of all parameters are correct
echo "Create '$project' folder for Ansible with Vault"
echo "$chemin"

if [ "$autoconfirm" = "yes" ]
then 
    echo "next step"
else
  read -p 'Please confirm with return [any other letter stop]: ' confirm
  if [ -z "$confirm" ]
  then 
    echo "next step"
  else
    fail "Exit"
  fi
fi

echo "Automatic creation of Ansible project with Vault linked to Mac Keychain"
#check and setup environnement
echo "0-Check and setup environnement"

#  0-python installed anf check version, need modern python, > 3.7
#https://stackoverflow.com/questions/6141581/detect-python-version-in-shell-script

version=$(python -c 'import platform; print(platform.python_version())' 2>&1)
parsedVersion=$(echo "${version//./}")
if [ "$parsedVersion" -gt "370" ]
then 
    echo "0-OK Modern python used = $version"
else
    fail "0-BAD need modern python > 3.7, current = $version, please install Anaconda > 3.7"
fi
echo "next step"

#  0-check if Python keyring need to be installed
keyring=$(python -c 'import pkgutil; print(1 if pkgutil.find_loader("keyring") else 0)' 2>&1)
if [ "$keyring" -eq "1" ]
then 
    echo "0-OK Python keyring installed"
else
    installed=$(python -m pip install keyring 2>&1)
    echo "0-Install keyring = $installed"
fi
echo "next step"

# -search keyring default emplacement
# python -c "import keyring.util.platform_; print(keyring.util.platform_.data_root())"
keyringpath=$(python -c 'import keyring.util.platform_; print(keyring.util.platform_.data_root())' 2>&1)

# -create the default config
# touch /Users/lk/.local/share/python_keyring
# 

if [ ! -e "$keyringpath" ] ; then
    touch "$keyringpath"

    # check if writable
    if [ ! -w "$keyringpath" ] ; then
       fail "0-Cannot write to keyring config = $keyringpath"
    else

      #create the file with content
      cat > $keyringpath << ENDOFFILE
[backend]
default-keyring=keyring.backends.OS_X.Keyring
ENDOFFILE

      echo "0-Create default keyring config = $keyringpath"
    fi
else
    echo "0-Default keyring config exist = $keyringpath"
fi
echo "next step"

#OK, the minimum environment installed, check if brew installed as default path

if [ ! -f /usr/local/bin/brew ]; then
    echo "0-Brew installation detected"
fi


#Create the Ansible environment for this project !
echo ""
echo "1-Create the Ansible environment for the project = $project"

mkdir $chemin/$project
mkdir $chemin/$project/provision
mkdir $chemin/$project/provision/roles
mkdir $chemin/$project/provision/facts-caching
mkdir $chemin/$project/provision/environments
mkdir $chemin/$project/provision/tmp
mkdir $chemin/$project/provision/files


cat > $chemin/$project/provision/environments/prod << ENDOFFILE
[$project]
localhost
ENDOFFILE


cat > $chemin/$project/provision/vars.yml << ENDOFFILE
---
# variables for the project $project

ENDOFFILE


cat > $chemin/$project/provision/.key << ENDOFFILE
#!/bin/bash
python -m keyring get ansible $project
ENDOFFILE


cat > $chemin/$project/provision/ansible.cfg << ENDOFFILE
[defaults]
#remove warning when executing playbook
deprecation_warnings = False
#use keychain to store vault password
vault_password_file = .key
#use debugger by default
strategy = debug

remote_user = vagrant
inventory   = environments/prod
# additional paths to search for roles in, colon separated
#    base roles_path    = /etc/ansible/roles
roles_path    = roles

retry_files_save_path = tmp
host_key_checking = False
log_path = ansible.log
hash_behaviour=merge

# activate cache caching using yaml file
fact_caching = yaml
# where is the fact file
#fact_caching_connection = /tmp/facts
# new path
fact_caching_connection = facts-caching
ENDOFFILE


cat > $chemin/$project/provision/install.yml << ENDOFFILE
---
- name: set $project server
  hosts: $project
  become: true
  become_user: root

  vars_files:
  - vars.yml

  pre_tasks:
  - name: set timezone to Europe/Zurich
    #set the right timezone
    # ubuntu = sudo timedatectl set-timezone Europe/Zurich
    timezone:
      name: Europe/Zurich
    
ENDOFFILE


cat > $chemin/$project/provision/vars.yml << ENDOFFILE
---
# variables for the project $project

ENDOFFILE


cat > $chemin/$project/provision/.gitignore << ENDOFFILE
#pas de scories Mac
.DS_Store

#pas de fichier .key
.key

ENDOFFILE


#Create the Ansible Vault connection with Mac Keychain
echo ""
echo "2-Create the Ansible Vault connection with Mac Keychain for the project = $project"

#the .key fine need to be executable and readwrite only by the current user
chmod 700 $chemin/$project/provision/.key

#Create the key for this project
#generate the random key
key=$(openssl rand -base64 30 2>&1)

#Save the key inside Mac Keychain
# python -c "import keyring; keyring.set_password('ansible', 'autosetup', 'random')"
keychain=$(python -c "import keyring; keyring.set_password('ansible', '$project', '$key')" 2>&1)

# display the instructions
echo ""
echo "#9-Usage:"
echo "#You don't need to specify the password when you run a playbook or encrypt a variable"
echo "# - Each project have a specific encryption key stored in your KeyChain"
echo "# - No encrytion by mistake published on GitHub"
echo "# - Without the encryption key, your playbook don't include any protected vacraiable with Ansible Vault"
echo ""
echo "#9.1 go to the project 'provision' folder"
echo "cd provision"
echo "# or"
echo "cd $chemin/$project/provision"
echo ""
echo "#9.2 Auto encrypt a value to a variable"
echo "ansible-vault encrypt_string 'secret' --name 'password'"
echo "# or append to the vars.yml file"
echo "ansible-vault encrypt_string 'secret' --name 'password' >> vars.yml"
echo ""
echo "#9.3 Run a playbook with Ansible Vault encrypted "
echo "ansible-playbook install.yml"
echo ""
echo "#9.4 Add a galaxy role "
echo "ansible-galaxy install author.role"
echo ""
echo "#9.9 generate a new encrytion key"
echo "#WARNING: All encrypted value will be lost if you don't have a backup"
echo "python -c \"import keyring; keyring.set_password('ansible', '$project', 'new_encryption_key')\""
echo ""

#write the project description
cat > $chemin/$project/$project.md << ENDOFFILE
# $project = [description of this project]

## Use Ansible to setup the VM

Go to the right place

\`\`\`
cd $chemin/$project
\`\`\`


#### All structure self created by autosetup role

\`\`\`
$project
├── provision
│   ├── ansible.cfg
│   ├── environments
│   │   └── prod
│   ├── facts-caching
│   ├── files
│   ├── install.yml
│   ├── roles
│   ├── tmp
│   └── vars.yml
└── $project.md
\`\`\`

## In the detail

### folder [$project]

This folder **$project**, contains everything.
At this level of the hierarchy, the Vagrant File and all documentation. 

#### folder [provision]

Folder **provision** contain all the Ansible Environment.
Need to be inside to start all processes of encryption and decryption.

\`\`\`
cd provision
cd $chemin/$project/provision
\`\`\`

##### ansible.cfg

The key of the organization.

##### vars.yml

All variables of this project **$project**

When you need to encrypt with Ansible Vault a variable, you don\'t need to take care of the encryption key.

\`\`\`
cd provision
cd $chemin/$project/provision

# Auto encrypt value to a variable
ansible-vault encrypt_string 'secret' --name 'password'
# or append to the vars.yml file
ansible-vault encrypt_string 'secret' --name 'password' >> vars.yml
\`\`\`

##### roles

The container of all roles needed for the project **$project**

If you want to add a role from Ansible Galaxy:

\`\`\`
cd provision
cd $chemin/$project/provision

# Add a galaxy role 
ansible-galaxy install author.role
\`\`\`


##### environments/prod

The host file [prod] inside the [environments] folder.
If you have multiple environment, create multiple host file.

## The secret

The \`provision\` folder has a hidden gem file \`.key\`.

\`\`\`
python -m keyring get ansible $project
\`\`\`

This \`.key\` file will be executable (\`chmod 700 .key\`)

If you want to remember the encryption key for this project **$project**

\`\`\`
cd $chemin/$project/provision
./.key
\`\`\`


### The underlying process

When you use Ansible Vault to encrypt a variable, you have two choices:
1. Move the encryption key in another place in clear text.
2. Enter the password at every run

The idea of this work is to protect the encryption key with the logging session.
The simplest way is to use the integrated process included in the OS.
On the Mac, this is Keychain Access application.

A Python library is used to be a platform independent .
It will be used on Gnome CentOS with a small modification.
Probably it\'s work in Windows too.

The second idea is to define a workspace for each project with a dedicated encryption key.
When you want to move a project to another computer, you just need to enter the correct encryption key inside the keychain.

Because Ansible Vault encryption key is separated from the normal computer space, it\'s reduce the risk of secret diclosure.
When your project is published on GitHub, the encrypted key of your Ansible Vaul is never present.
I also added the .key file in .git ignore as a precaution.

If you use a modern Mac with T2 chips, and you encrypt the disk, the only way to recover your login password is using the recovery key.
After, the initialization process of the new password erase all user Keychain data.
To recover the secret encrypted with Ansible Vault, you just need to reenter the encryption key in keychain.

#### In the detail :

\`\`\`
ansible.cfg -> vault_password_file = .key
└── .key -> python -m keyring get ansible $project
    └── Mac OS Keyring
        └── ansible $project -> encryption key
\`\`\`

* The \`ansible.cfg\` contain a link to vault password_file \`.key\`
* The vault password_file \`.key\` contain a small python code
  * The small python code uses the library keyring to link the internal MacOS Keychain Access application
    \`\`\`
    python -m keyring get ansible $project
    \`\`\`

* The MacOS Keychain Access application conserve all your secret linked to your login.
https://support.apple.com/guide/keychain-access/what-is-keychain-access-kyca1083/mac

#### Change the encrypted password used by this project : 

The initial password is self-generated, if you want to change it please use this small code in the terminal.

\`\`\`
# WARNING: All encrypted value will be lost if you don't have a backup
python -c "import keyring; keyring.set_password('ansible', '$project', 'new_encryption_key')"
\`\`\`

#### FAQ:
* Why use keyring library ?
  * This process becomes platform agnostics, it runs well on Linux (tested) and Windows (not tested).
* Why using python ?
  * This is the language of the future, more prosaic it\'s the language used by Ansible.
* Why needed python 3.7 ?
  * Because python 2.7 is depreciated now.
* Why you recommend using Anaconda ?
  * The simplest way to have python 3.7 installed on your Mac, Linux and Windows.
* Why use a bash to do the job ?
  * The chicken and egg problem, useable if Ansible is not installed.

ENDOFFILE

