# -*- encoding: utf-8 -*-
require File.expand_path('../lib/pushy_client/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Mark Anderson"]
  gem.email         = ["mark@chef.io"]
  gem.description   = %q{Client for Chef push jobs server}
  gem.summary       = %q{Client for Chef push jobs server}
  gem.homepage      = "https://github.com/chef/opscode-pushy-client"

  gem.executables   = Dir.glob('bin/**/*').map{|f| File.basename(f)}
  gem.files         = %w{opscode-pushy-client.gemspec Gemfile Rakefile LICENSE} + Dir.glob('{bin,lib,spec, keys}/**/*').reject{|f| File.directory?(f)}
  gem.test_files    = Dir.glob('{test,spec,features}/**/*')
  gem.name          = "opscode-pushy-client"
  gem.require_paths = ["lib"]
  gem.version       = PushyClient::VERSION

  gem.required_ruby_version = '>= 2.5'

  gem.add_dependency "chef", ">= 14.0", "< 16.0"
  gem.add_dependency "ohai", ">= 14.0", "< 16.0"
  gem.add_dependency "ffi-rzmq"
  gem.add_dependency "uuidtools"

  %w(rake rspec rspec_junit_formatter).each do |dep|
    gem.add_development_dependency dep
  end
end
