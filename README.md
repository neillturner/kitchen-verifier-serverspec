[![Gem Version](https://badge.fury.io/rb/kitchen-verifier-serverspec.svg)](http://badge.fury.io/rb/kitchen-verifier-serverspec)
[![Gem Downloads](http://ruby-gem-downloads-badge.herokuapp.com/kitchen-verifier-serverspec?type=total&color=brightgreen)](https://rubygems.org/gems/kitchen-verifier-serverspec)
[![Build Status](https://travis-ci.org/neillturner/kitchen-verifier-serverspec.png)](https://travis-ci.org/neillturner/kitchen-verifier-serverspec)

# Kitchen::Verifier::Serverspec

A Test Kitchen Serverspec Verifer without having to transit the Busser layer.

This supports running serverspec both remotely on the server and locally on your workstation.
Runners are supported to provide logic to run serverspec initially supporting ansiblespec.


## Installation

On your workstation add this line to your Gemfile:

    gem 'kitchen-verifier-serverspec'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install kitchen-verifier-serverspec

When it runs it install serverspec on the remote server or the workstation if remote_exec set to false.
This can be configured by passing a Gemfile like this:

```
source 'https://rubygems.org'

gem 'net-ssh','~> 2.9'
gem 'serverspec'
```

this allows extra dependencies to be specified and the version of serverspec specified.

# Serverspec Verifier Options

key | default value | Notes
----|---------------|--------
additional_install_commmand | nil | Additional shell command to be used at install stage. Can be multiline. See examples below.
additional_serverspec_command | nil | additional command to run serverspec. Can be multiline. See examples below.
bundler_path | | override path for bundler command
color | true | enable color in the output
custom_install_commmand | nil | Custom shell command to be used at install stage. Can be multiline. See examples below.
custom_serverspec_command | nil | custom command to run serverspec. Can be multiline. See examples below.
default_path | '/tmp/kitchen' | Set the default path where serverspec looks for patterns
default_pattern | false | use default dir behaviour of busser i.e. test/integration/SUIT_NAME/serverspec/*_spec.rb
env_vars | {} | environment variable to set for rspec and can be used in the spec_helper. It will automatically pickup any environment variables set with a KITCHEN_ prefix.
extra_flags | nil | extra flags to add to ther serverspec command
format | 'documentation' | format of serverspec output
gemfile | nil | custom gemfile to use to install serverspec
http_proxy | nil | use http proxy when installing ruby, serverspec and running serverspec
https_proxy | nil | use https proxy when installing puppet, ruby, serverspec and running serverspec
patterns | [] | array of patterns for spec test files
remote_exec | true | specify false to run serverspec on workstation
remove_default_path | false | remove the default_path after successful serverspec run
require_runner | false | run the custom runner instead of rspec directly
rspec_path | | override path for rspec command
runner_url | https://raw.githubusercontent.com /neillturner/serverspec-runners/ master/ansiblespec_runner.rb | url for custom runner
sleep | 0 |
sudo | nil | use sudo to run commands
sudo_command | 'sudo -E -H' | sudo command to run when sudo set to true
test_serverspec_installed | true | only run install_command if serverspec not installed

## Tips

If you get errors like 'Bundler installed as root, can't be found' then you will need to set the paths. Its hard to get the default paths correct when ruby maybe installed in a different user.
```
bundler_path: '/usr/local/bin'
rspec_path: '/usr/local/bin'
```

## Usage

There are three ways to run verifier serverspec:
  * Remotely directly on the server running serverspec in exec mode
  * Remotely directly on the server running serverspec in ssh mode
  * Locally on your workstation running serverspec in ssh mode

Verifier Serverspec allows the serverspec files to be anywhere in the repository or in the test-kitchen default location i.e /test/integration. This means that you can use spec files that follow ansiblespec or puppet beaker locations.

### Windows  

A good example of using severspec wit windows can be found at:
* https://github.com/josephkumarmichael/centos-serverspec-windows-testbed
* Windows spec_helper.rb sample: https://github.com/josephkumarmichael/centos-serverspec-windows-testbed/blob/master/tests/spec/spec_helper.rb fput this in the spec folder. Then specify full path to the spec_helper in the default_spec test.

### Spec File Location and Updating

When remote_exec is set to true (the default) the following rules apply for getting the spec files to the remote server instance.

if default_pattern is set to true then Verifier Serverspec copies the spec files in the test/integration directory like the busser serverspec that is supplied by chef.

if default_pattern is set to false (the default) then Verfier Serverspec does not copy the the serverspec files. They are assumed to be there in the repository and to have been copied to the server via the provisioner. This means in this case if you change a spec file you need to run converge again to get the spec files copied to the server.
A future enhancement maybe to copy these files so the provisioner doesn't have to be called when they are changed.


## Remotely directly on server running serverspec in exec mode

This allow testing directly on the server. Typicaly used in conjunction with ansible using local connection.

An example of the verifier serverspec options in your `.kitchen.yml` file:

```yaml
verifier:
  name: serverspec

suites:
  - name: base
    verifier:
      patterns:
      - modules/mycompany_base/spec/acceptance/base_spec.rb
```

See example [https://github.com/neillturner/puppet_repo](https://github.com/neillturner/puppet_repo)

```yaml
verifier:
  name: serverspec

suites:
  - name: base
    verifier:
      patterns:
      - roles/tomcat/spec/tomcat_spec.rb
      bundler_path: '/usr/local/bin'
      rspec_path: '/usr/local/bin'
```

See example [https://github.com/neillturner/ansible_repo](https://github.com/neillturner/ansible_repo)

The spec/spec_helper.rb should contain

```
require 'serverspec'
set :backend, :exec
```


## Remotely directly on the server running serverspec in ssh mode

This allow testing of multiple remote servers. Typicaly used in conjunction with ansible using ssh connection.

```yaml
verifier:
  name: serverspec

suites:
  - name: base
    verifier:
      patterns:
      - roles/tomcat/spec/tomcat_spec.rb
      bundler_path: '/usr/local/bin'
      rspec_path: '/home/vagrant/bin'
      env_vars:
        TARGET_HOST: 172.28.128.7
        LOGIN_USER: vagrant
        SSH_KEY: 'spec/tomcat_private_key.pem'
```

The spec/spec_helper.rb should contain

```
require 'rubygems'
require 'bundler/setup'

require 'serverspec'
require 'pathname'
require 'net/ssh'

RSpec.configure do |config|
  set :host,  ENV['TARGET_HOST']
  # ssh options at http://net-ssh.github.io/ssh/v1/chapter-2.html
  # ssh via password, set :version to :debug for debugging
  #set :ssh_options, :user => ENV['LOGIN_USER'], :paranoid => false, :verbose => :info, :password => ENV['LOGIN_PASSWORD'] if ENV['LOGIN_PASSWORD']
  # ssh via ssh key
  set :ssh_options, :user => ENV['LOGIN_USER'], :paranoid => false, :verbose => :error, :host_key => 'ssh-rsa', :keys => [ ENV['SSH_KEY'] ] if ENV['SSH_KEY']
  set :backend, :ssh
  set :request_pty, true
end
```

## Locally on your workstation running serverspec in ssh mode

This allows you not to have to install ruby and serverspec on the server being configured as serverspec is run on your workstation in ssh mode.
```yaml
verifier:
  name: serverspec
  remote_exec: false

suites:
  - name: base
    provisioner:
      custom_facts:
        role_name1: base
    verifier:
      patterns:
      - modules_mycompany/mycompany_base/spec/acceptance/base_local_spec.rb

```

Set environment variables dynamically on your workstation
```
export KITCHEN_HOST=127.0.0.1
export KITCHEN_PORT=2222
export KITCHEN_USERNAME=vagrant
export KITCHEN_SSH_KEY='c:/repository/puppet_repo/private_key.pem'
Or for Windows Workstations:
set KITCHEN_HOST=127.0.0.1
set KITCHEN_PORT=2222
set KITCHEN_USERNAME=vagrant
set KITCHEN_SSH_KEY='c:/repository/puppet_repo/private_key.pem'
```

The spec/spec_helper.rb should contain

```
require 'rubygems'
require 'bundler/setup'

require 'serverspec'
require 'pathname'
require 'net/ssh'

RSpec.configure do |config|
  set :host, ENV['KITCHEN_HOSTNAME']
  # ssh options at http://net-ssh.github.io/net-ssh/Net/SSH.html#method-c-start
  # ssh via ssh key (only)
  set :ssh_options,
    :user => ENV['KITCHEN_USERNAME'],
    :port => ENV['KITCHEN_PORT'],
    :auth_methods => [ 'publickey' ],
    :keys => [ ENV['KITCHEN_SSH_KEY'] ],
    :keys_only => true,
    :paranoid => false,
    :verbose => :error
  set :backend, :ssh
  set :request_pty, true
end
```


# Custom Runners

Custon runners can be defined and run to provide further customization.
There is a runner that automatically runs the ansiblespec files for all the hosts from the
ansible provisioner.

This can be run by specifying in the kitchen yml file:

```yaml
verifier:
  name: serverspec

suites:
  - name: base
    verifier:
      runner_url: https://raw.githubusercontent.com/neillturner/serverspec-runners/master/ansiblespec_runner.rb
      require_runner: true
      bundler_path: '/usr/local/bin'
      rspec_path: '/home/vagrant/bin'
      env_vars:
        TARGET_HOST: 172.28.128.7
        LOGIN_USER: vagrant
        SSH_KEY: 'spec/tomcat_private_key.pem'
```

#### custom_install_command example usage

* One liner
```yaml
    custom_install_command: yum install -y git
```
* Multiple lines, a.k.a embed shell script
```yaml
  custom_install_command: |
     command1
     command2
```
* Multiple lines join without new line
```yaml
  custom_install_command: >
     command1 &&
     command2
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Run style checks and RSpec tests (`bundle exec rake`)
4. Commit your changes (`git commit -am 'Add some feature'`)
5. Push to the branch (`git push origin my-new-feature`)
6. Create new Pull Request
