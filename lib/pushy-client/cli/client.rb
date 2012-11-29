require 'chef/application'
require 'chef/config'
require 'chef/log'
require 'pushy-client/client/app'
require 'pushy-client/client/log'

module PushyClient
  module CLI
    class Client < Chef::Application

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

      # Pushy-only options

      option :offline_threshold,
        :long => "--offline-threshold THRESHOLD",
        :default => 3,
        :description => "Number of missed intervals before I stop sending a heartbeat"

      option :online_threshold,
        :long => "--online-threshold THRESHOLD",
        :default => 2,
        :description => "Number of messages to receive after disconnect before I start sending a heartbeat"

      option :interval,
        :short => "-i INTERVAL",
        :long => "--interval INTERVAL",
        :default => 1,
        :description => "How often do I send a heartbeat"

      option :lifetime,
        :short => "-r TIMEOUT",
        :long => "--lifetime TIMEOUT",
        :default => 3600,
        :description => "How often do restart the client"

      option :out_address,
        :long => "--out-address HOST",
        :default => "tcp://127.0.0.1:10000",
        :description => "URL pointing to the server's heartbeat broadcast service"

      option :server_public_key_path,
        :long => "--server-key KEY_FILE",
        :description => "Set the client key file location",
        :default => File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'keys', 'server_public.pem')),
        :proc => nil

      def reconfigure
        # We do not use Chef's formatters.
        Chef::Config[:force_logger] = true
        # Set up our logger too (TODO get rid of this)
        PushyClient::Log.level = config[:log_level] || :debug
        super
      end

      def setup_application
      end

      def run_application
        if Chef::Config[:version]
          puts "Pushy version: #{::PushyClient::VERSION}"
        end

        app = PushyClient::App.new(
          :service_url_base        => Chef::Config[:chef_server_url],
          :client_private_key_path => Chef::Config[:client_key],
          :node_name               => Chef::Config[:node_name]
        )

        app.start
      end
    end
  end
end
