# @copyright Copyright 2014 Chef Software, Inc. All Rights Reserved.
#
# This file is provided to you under the Apache License,
# Version 2.0 (the "License"); you may not use this file
# except in compliance with the License. You may obtain
# a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied. See the License for the
# specific language governing permissions and limitations
# under the License.
#

require 'chef/application'
require 'chef/config'
# This is needed for compat with chef-client >= 11.8.0.
# To keep compat with older chef-client, rescue if not found
require 'chef/config_fetcher' rescue 'assuming chef-client < 11.8.0'
require 'chef/log'
require_relative '../pushy_client'
require_relative '../pushy_client/version'

class PushyClient
  class CLI < Chef::Application

    def self.find_default_config
      configs = ['chef-push-client.rb', 'push-jobs-client.rb', 'client.rb']
      base = "/etc/chef"
      paths = configs.map {|c| Chef::Config.platform_specific_path(File.join(base, c)) }
      path = paths.detect {|p| File.exist?(p) }
      # todo make debug before commit
      Chef::Log.info("Push Client using default config file path: '#{path}'")
      path
    end

    option :config_file,
      :short => "-c CONFIG",
      :long  => "--config CONFIG",
      :default => find_default_config,
      :description => "The configuration file to use"

    option :log_level,
      :short        => "-l LEVEL",
      :long         => "--log_level LEVEL",
      :description  => "Set the log level (debug, info, warn, error, fatal)",
      :proc         => lambda { |l| l.to_sym }

    option :log_location,
      :short        => "-L LOGLOCATION",
      :long         => "--logfile LOGLOCATION",
      :description  => "Set the log file location, defaults to STDOUT - recommended for daemonizing",
      :proc         => nil

    option :help,
      :short        => "-h",
      :long         => "--help",
      :description  => "Show this message",
      :on           => :tail,
      :boolean      => true,
      :show_options => true,
      :exit         => 0

    option :node_name,
      :short => "-N NODE_NAME",
      :long => "--node-name NODE_NAME",
      :description => "The node name for this client",
      :proc => nil

    option :chef_server_url,
      :short => "-S CHEFSERVERURL",
      :long => "--server CHEFSERVERURL",
      :description => "The chef server URL",
      :proc => nil

    option :client_key,
      :short        => "-k KEY_FILE",
      :long         => "--client_key KEY_FILE",
      :description  => "Set the client key file location",
      :proc         => nil

    option :version,
      :short        => "-v",
      :long         => "--version",
      :description  => "Show push client version",
      :boolean      => true,
      :proc         => lambda {|v| puts "Push Client: #{::PushyClient::VERSION}"},
      :exit         => 0

    option :file_dir,
      :short        => "-d DIR",
      :long         => "--file_dir DIR",
      :description  => "Set the directory for temporary files",
      :default      => "/tmp/chef-push",
      :proc         => nil

    option :allow_unencrypted,
      :long        => "--allow_unencrypted",
      :boolean     => true,
      :description => "Allow unencrypted connections to 1.x servers"

    def reconfigure
      # We do not use Chef's formatters.
      Chef::Config[:force_logger] = true
      super
    end

    def setup_application
    end

    def shutdown(ret_code = 0)
        @client.stop if @client
        exit(ret_code)
    end

    def run_application
      if Chef::Config[:version]
        puts "Push Client version: #{::PushyClient::VERSION}"
      end

      ohai = Ohai::System.new
      ohai.load_plugins
      ohai.run_plugins(true, ['hostname'])

      @client = PushyClient.new(
        :chef_server_url => Chef::Config[:chef_server_url],
        :client_key      => Chef::Config[:client_key],
        :node_name       => Chef::Config[:node_name] || ohai[:fqdn] || ohai[:hostname],
        :whitelist       => Chef::Config[:whitelist] || { 'chef-client' => 'chef-client' },
        :hostname        => ohai[:hostname],
        :filedir         => Chef::Config[:file_dir],
        :allow_unencrypted => Chef::Config[:allow_unencrypted]
      )

      @client.start

      # install signal handlers
      # Windows does not support QUIT and USR1 signals
      exit_signals = if Chef::Platform.windows?
                       ["TERM", "INT"]
                     else
                       ["TERM", "QUIT", "INT"]
                     end

      exit_signals.each do |sig|
        Signal.trap(sig) do
          puts "received #{sig}, shutting down"
          shutdown(0)
        end
      end

      unless Chef::Platform.windows?
        Signal.trap("USR1") do
          puts "received USR1, reconfiguring"
          @client.trigger_reconfigure
        end
      end

      # Block forever so that client threads can run
      while true
        sleep 3600
      end
    end
  end
end
