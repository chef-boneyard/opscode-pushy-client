#
# Author:: Mark Anderson (<mark@opscode.com>)
# Copyright:: Copyright (c) 2012 Opscode, Inc.
# All rights reserved
#

require "bundler/gem_tasks"
require_relative "tasks/bundle"

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
