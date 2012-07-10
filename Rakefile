#
# Author:: Mark Anderson (<mark@opscode.com>)
# Copyright:: Copyright (c) 2012 Opscode, Inc.
# All rights reserved
#

require 'rubygems'
require 'rake'
require 'bundler/gem_tasks'

require 'rake/gempackagetask'
require 'rubygems/specification'
require 'date'


gemspec = eval(File.read('pushy-client.gemspec'))

Rake::GemPackageTask.new(gemspec).define

desc "install the gem locally"
task :install => :package do
  sh %{gem install pkg/#{gemspec.name}-#{gemspec.version}}
end

begin
  require 'rspec/core/rake_task'

  RSpec::Core::RakeTask.new(:spec) do |spec|
    spec.rspec_opts = ['--options', "\"#{File.dirname(__FILE__)}/spec/spec.opts\""]
    spec.pattern = 'spec/**/*_spec.rb'
  end

  RSpec::Core::RakeTask.new(:rcov) do |spec|
    spec.pattern = 'spec/**/*_spec.rb'
    spec.rcov = true
  end
rescue LoadError
  task :spec do
    abort "RSpec is not available. (sudo) gem install rspec to run unit tests"
  end
end


