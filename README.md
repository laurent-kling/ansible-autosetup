autosetup - Automatic creation of Ansible project with Vault linked to Mac Keychain
=========

When you use Ansible Vault to encrypt a variable, you have two choices:

1. Move the encoding key in another place in clear text.
2. Enter the password at every run

The idea of this work is to automatically protect the encryption key with the logging session.
The simplest way is to use the integrated process included in the OS, Keychain Access application.

When you require to encrypt with Ansible Vault a variable, you don't need to take care of the encoding key.

```
cd provision

# Auto encrypt value to a variable
ansible-vault encrypt_string 'secret' --name 'password'
# or append to the vars.yml file
ansible-vault encrypt_string 'secret' --name 'password' >> vars.yml
```

The second idea is to define a workspace for each project with a dedicated encoding key.
When you want to move a project to another computer, you just need to enter the correct encoding key inside the keychain.

A full documentation in MarkDown is automatically generated describing the methods.

Ansible Vault encoding key is separated from the normal computer space, it's reduce the risk of diclosure a secret. When your project is published on GitHub, the encoding key of your Ansible Vault is never present. I also added the .key file in .git ignore as a precaution.

If you use a modern Mac with T2 chips, and you encrypt the disk, the only way to recover your login password is using the recovery key.
After, the initialization process of the new password erase all user Keychain data.
To recover the secret encrypted with Ansible Vault, you just need to reenter the encryption key in keychain.

Requirements
------------

* Mac OS X

Role Variables
--------------

By default, these 2 variables need to be defined:

1. **project**: [Required] 

   Name of the Ansible project using Vault

2. **path**: [Required] 

   Path where of the project folder will be created

Example Playbook
----------------

To installing this role from ansible-galaxy

```
ansible-galaxy install laurent_kling.autosetup
```

Including an example of how to use it with required variables :

    # use this local computer to interact with ansible
    - hosts: localhost
      connection: local
      gather_facts: yes
    
      roles:
        - role: laurent_kling.autosetup
          project: "ansible-vault"
          path: "~/Documents"


License
-------

MIT

Author Information
------------------

[Laurent Kling](https://people.epfl.ch/laurent.kling/?lang=en) @ [EPFL - STI - IT](https://sti-it.epfl.ch/)

## Version

### V1.0.0

*Released: April 6, 2020*

- Initial release



----------------