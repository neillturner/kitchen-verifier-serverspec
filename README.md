[![Gem Version](https://badge.fury.io/rb/kitchen-verifier-serverspec.svg)](http://badge.fury.io/rb/kitchen-verifier-serverspec)
[![Gem Downloads](http://ruby-gem-downloads-badge.herokuapp.com/kitchen-verifier-serverspec?type=total&color=brightgreen)](https://rubygems.org/gems/kitchen-verifier-serverspec)
[![Build Status](https://travis-ci.org/neillturner/kitchen-verifier-serverspec.png)](https://travis-ci.org/neillturner/kitchen-verifier-serverspec)

# Kitchen::Verifier::Serverspec

A Test Kitchen Serverspec Verifer without having to transit the Busser layer.


## Installation

Add this line to your application's Gemfile:

    gem 'kitchen-verifier-serverspec'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install kitchen-verifier-serverspec

## Usage


An example of the verifier serverspec options in your `.kitchen.yml` file:

```yaml
verifier:
  name: serverspec

suites:
  - name: base
    verifier:
      patterns:
      - mycompany_base/spec/acceptance/base_spec.rb
```

See example [https://github.com/neillturner/puppet_beaker_repo](https://github.com/neillturner/puppet_beaker_repo)

# Serverspec Verifier Options

key | default value | Notes
----|---------------|--------
sleep | 0 |
serverspec_command | nil | custom command to run serverspec
format | 'documentation' | format of serverspec output
color | true | Enable color in the output
default_path | '/tmp/kitchen' | Set the default path where serverspec looks for patterns
patterns | [] | array of patterns for spec test files
gemfile | nil | custom gemfile to use to install serverspec
install_commmand | 'bundle install' | command to install serverspec
test_serverspec_installed | true | only run install_command if serverspec not installed
extra_flags | nil | extra flags to add to ther serverspec command
remove_default_path | false | remove the default_path after successful serverspec run


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Run style checks and RSpec tests (`bundle exec rake`)
4. Commit your changes (`git commit -am 'Add some feature'`)
5. Push to the branch (`git push origin my-new-feature`)
6. Create new Pull Request
