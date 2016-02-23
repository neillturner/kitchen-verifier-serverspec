[![Gem Version](https://badge.fury.io/rb/kitchen-verifier-serverspec.svg)](http://badge.fury.io/rb/kitchen-verifier-serverspec)
[![Gem Downloads](http://ruby-gem-downloads-badge.herokuapp.com/kitchen-verifier-serverspec?type=total&color=brightgreen)](https://rubygems.org/gems/kitchen-verifier-serverspec)
[![Build Status](https://travis-ci.org/neillturner/kitchen-verifier-serverspec.png)](https://travis-ci.org/neillturner/kitchen-verifier-serverspec)

# Kitchen::Verifier::Serverspec

A Test Kitchen Serverspec Verifer without having to transit the Busser layer.

This supports running supports running serverspec but remotely on the server and locally on your workstation.
In the next version runners will be supported to provide logic to run serverspec initially supporting ansiblespec.


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

## Usage


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

or with environment variables

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

or run on your workstation

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
      env_vars:
        TARGET_HOST: 127.0.0.1
        TARGET_PORT: 2222
        LOGIN_USER: vagrant
        SSH_KEY: 'c:/repository/puppet_beaker_repo/private_key.pem'
```

# Serverspec Verifier Options

key | default value | Notes
----|---------------|--------
sleep | 0 |
remote_exec | true | specify false to run serverspec on workstation
serverspec_command | nil | custom command to run serverspec
format | 'documentation' | format of serverspec output
color | true | enable color in the output
default_path | '/tmp/kitchen' | Set the default path where serverspec looks for patterns
patterns | [] | array of patterns for spec test files
gemfile | nil | custom gemfile to use to install serverspec
install_commmand | 'bundle install' | command to install serverspec
test_serverspec_installed | true | only run install_command if serverspec not installed
extra_flags | nil | extra flags to add to ther serverspec command
remove_default_path | false | remove the default_path after successful serverspec run
http_proxy | nil | use http proxy when installing ruby, serverspec and running serverspec
https_proxy | nil | use https proxy when installing puppet, ruby, serverspec and running serverspec
sudo | nil | use sudo to run commands
env_vars | {} | environment variable to set for rspec
bundle_path | nil | path for bundler command
rspec_path | nil | path for rspec command


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Run style checks and RSpec tests (`bundle exec rake`)
4. Commit your changes (`git commit -am 'Add some feature'`)
5. Push to the branch (`git push origin my-new-feature`)
6. Create new Pull Request
