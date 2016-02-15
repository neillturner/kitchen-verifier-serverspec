# encoding: utf-8

$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)

require 'kitchen/verifier/serverspec_version'

Gem::Specification.new do |s|
  s.name          = 'kitchen-verifier-serverspec'
  s.license       = 'Apache-2.0'
  s.version       = Kitchen::Verifier::SERVERSPEC_VERSION
  s.authors       = ['Neill Turner']
  s.email         = ['neillwturner@gmail.com']
  s.homepage      = 'https://github.com/neillturner/kitchen-verifier-serverspec'
  s.summary       = 'Serverspec verifier for Test-Kitchen without having to transit the Busser layer. '
  candidates = Dir.glob('{lib}/**/*') + ['README.md', 'kitchen-verifier-serverspec.gemspec']
  s.files = candidates.sort
  s.platform      = Gem::Platform::RUBY
  s.require_paths = ['lib']
  s.rubyforge_project = '[none]'
  s.add_dependency 'test-kitchen', '~> 1.4'
  s.description = <<-EOF
Serverspec verifier for Test-Kitchen without having to transit the Busser layer.
EOF
end
