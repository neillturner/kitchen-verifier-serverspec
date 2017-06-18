#require 'rubocop/rake_task'
#require 'rspec/core/rake_task'
#
#task default: [:rubocop, :spec]
#
#RuboCop::RakeTask.new
#
#RSpec::Core::RakeTask.new(:spec) do |t|
#  t.pattern = 'spec/**/*_spec.rb'
#end

require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:test) do |t|
  t.pattern = Dir.glob('spec/**/*_spec.rb')
#  t.rspec_opts = '--format documentation --require spec_helper'
end

task default: :test
