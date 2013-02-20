require 'chef/application'
require 'chef/config'
require 'chef/log'
require 'pushy_client'
require 'pushy_client/version'

class PushyClient
  class CLI < Chef::Application

    option :config_file,
      :short => "-c CONFIG",
      :long  => "--config CONFIG",
      :default => Chef::Config.platform_specific_path("/etc/chef/client.rb"),
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
      :description  => "Show pushy version",
      :boolean      => true,
      :proc         => lambda {|v| puts "Pushy: #{::PushyClient::VERSION}"},
      :exit         => 0

    def reconfigure
      # We do not use Chef's formatters.
      Chef::Config[:force_logger] = true
      super
    end

    def setup_application
    end

    def run_application
      if Chef::Config[:version]
        puts "Pushy version: #{::PushyClient::VERSION}"
      end

      ohai = Ohai::System.new
      ohai.require_plugin('os')
      ohai.require_plugin('hostname')

      client = PushyClient.new(
        :chef_server_url => Chef::Config[:chef_server_url],
        :client_key      => Chef::Config[:client_key],
        :node_name       => Chef::Config[:node_name] || ohai[:fqdn] || ohai[:hostname],
        :whitelist       => Chef::Config[:whitelist] || { 'chef-client' => 'chef-client' },
        :hostname        => ohai[:hostname]
      )

      client.start
      # Block forever so that client threads can run
      while true
        sleep 3600
      end
    end
  end
end
