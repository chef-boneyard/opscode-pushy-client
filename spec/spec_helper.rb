$:.unshift File.expand_path("../../lib", __FILE__)
$:.unshift File.expand_path("../..", __FILE__)

require 'bundler'
Bundler.require(:default, :test)

require 'pushy-client'

require 'ap'
require 'tmpdir'
require 'tempfile'

require 'spec/support/concern'

WATCH = lambda { |x| puts x } unless defined?(WATCH)

# Load everything from spec/support
# Do not change the gsub.
Dir["spec/support/**/*.rb"].map { |f| f.gsub(%r{.rb$}, '') }.each { |f| require f }

class TestConfig
  class << self
    attr_accessor :service_url_base
    attr_accessor :client_private_key_path
  end
end

RSpec.configure do |config|
  config.mock_with :rspec
  config.filter_run :focus => true
  config.filter_run_excluding :external => true

  config.run_all_when_everything_filtered = true
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.formatter = 'documentation'

  PushyClient::Log.level = :debug

  TestConfig.service_url_base = "http://33.33.33.10:10003/organizations/ponyville"
  TestConfig.client_private_key_path = File.expand_path(File.join(File.dirname(__FILE__), '..', 'keys', 'client_private.pem'))
end
