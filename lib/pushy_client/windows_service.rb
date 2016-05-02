#
# Author:: Christopher Maier (<maier@lambda.local>)
# Copyright:: Copyright (c) 2011 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/application'
require 'chef/config'
require 'chef/log'
require 'chef/rest'
require 'mixlib/cli'
require 'win32/daemon'
require_relative '../pushy_client'
require_relative '../pushy_client/cli'
require_relative '../pushy_client/version'

class PushyClient
  class WindowsService < ::Win32::Daemon
    include Mixlib::CLI

    option :config_file,
      :short => "-c CONFIG",
      :long => "--config CONFIG",
      :default => PushyClient::CLI.find_default_config,
      :description => "The configuration file to use"

    option :log_location,
      :short        => "-L LOGLOCATION",
      :long         => "--logfile LOGLOCATION",
      :description  => "Set the log file location",
      :default => "#{ENV['SYSTEMDRIVE']}/chef/push-client.log"

    option :allow_unencrypted,
      :long        => "--allow_unencrypted",
      :boolean     => true,
      :description => "Allow unencrypted connections to 1.x servers"

    def service_init
      @service_action_mutex = Mutex.new
      @service_signal = ConditionVariable.new

      reconfigure
      Chef::Log.info("Chef Push Jobs Client Service initialized")
    end

    def service_main(*startup_parameters)
      begin
        @service_action_mutex.synchronize do
          Chef::Log.info("Push Client version: #{::PushyClient::VERSION}")
          Chef::Log.info("Push Client started as service with parameters: #{startup_parameters}")
          Chef::Log.info("Push Client passed: #{ARGV.join(', ')}")
          reconfigure(startup_parameters)

          # Lifted from PushyClient::CLI
          ohai = Ohai::System.new
          ohai.load_plugins
          ohai.run_plugins(true, ['os', 'hostname'])

          @client = PushyClient.new(
                                    :chef_server_url => Chef::Config[:chef_server_url],
                                    :client_key      => Chef::Config[:client_key],
                                    :node_name       => Chef::Config[:node_name] || ohai[:fqdn] || ohai[:hostname],
                                    :whitelist       => Chef::Config[:whitelist] || { 'chef-client' => 'chef-client' },
                                    :hostname        => ohai[:hostname],
                                    :allow_unencrypted => Chef::Config[:allow_unencrypted]
                                    )

          @client.start
          Chef::Log.info("pushy-client is started...")

          # Wait until we get service exit signal
          @service_signal.wait(@service_action_mutex)
          Chef::Log.debug("Stopping pushy-client...")
          @client.stop
        end

      rescue Exception => e
        Chef::Log.error("#{e.class}: #{e}")
        Chef::Log.error("Terminating pushy-client service...")
        Chef::Application.debug_stacktrace(e)
      end

      Chef::Log.debug("Exiting service...")
    end

    ################################################################################
    # Control Signal Callback Methods
    ################################################################################

    def service_stop
      Chef::Log.info("STOP request from operating system.")
      while !@service_action_mutex.try_lock do
        Chef::Log.info("Pushy is being initialized waiting for initialization to complete.")
        sleep(1)
      end

      @service_signal.signal
      @service_action_mutex.unlock
    end

    def service_pause
      Chef::Log.info("PAUSE request from operating system.")
      Chef::Log.info("Pushy Client Service doesn't support PAUSE.")
      Chef::Log.info("Pushy Client Service is still running.")
    end

    def service_resume
      Chef::Log.info("RESUME signal received from the OS.")
    end

    def service_shutdown
      Chef::Log.info("SHUTDOWN signal received from the OS.")

      # Treat shutdown similar to stop.

      service_stop
    end

    ################################################################################
    # Internal Methods
    ################################################################################

    private

    def apply_config(config_file_path)
      Chef::Config.from_file(config_file_path)
      Chef::Config.merge!(config)
    end

    # Lifted from Chef::Application, with addition of optional startup parameters
    # for playing nicely with Windows Services and logic from PushyClient::CLI
    def reconfigure(startup_parameters=[])
      Chef::Config[:force_logger] = true

      configure_chef startup_parameters
      configure_logging
    end

    # Lifted from application.rb
    # See application.rb for related comments.

    def configure_logging
      Chef::Log.init(Chef::Config[:log_location])
      if want_additional_logger?
        configure_stdout_logger
      end
      Chef::Log.level = resolve_log_level
    end

    def configure_stdout_logger
      stdout_logger = Logger.new(STDOUT)
      STDOUT.sync = true
      stdout_logger.formatter = Chef::Log.logger.formatter
      Chef::Log.loggers <<  stdout_logger
    end

    # Based on config and whether or not STDOUT is a tty, should we setup a
    # secondary logger for stdout?
    def want_additional_logger?
      ( Chef::Config[:log_location] != STDOUT ) && STDOUT.tty? && (!Chef::Config[:daemonize]) && (Chef::Config[:force_logger])
    end

    # Use of output formatters is assumed if `force_formatter` is set or if
    # `force_logger` is not set and STDOUT is to a console (tty)
    def using_output_formatter?
      Chef::Config[:force_formatter] || (!Chef::Config[:force_logger] && STDOUT.tty?)
    end

    def auto_log_level?
      Chef::Config[:log_level] == :auto
    end

    # if log_level is `:auto`, convert it to :warn (when using output formatter)
    # or :info (no output formatter). See also +using_output_formatter?+
    def resolve_log_level
      if auto_log_level?
        if using_output_formatter?
          :warn
        else
          :info
        end
      else
        Chef::Config[:log_level]
      end
    end

    def configure_chef(startup_parameters)
      # Bit of a hack ahead:
      # It is possible to specify a service's binary_path_name with arguments, like "foo.exe -x argX".
      # It is also possible to specify startup parameters separately, either via the the Services manager
      # or by using the registry (I think).

      # In order to accommodate all possible sources of parameterization, we first parse any command line
      # arguments.  We then parse any startup parameters.  This works, because Mixlib::CLI reuses its internal
      # 'config' hash; thus, anything in startup parameters will override any command line parameters that
      # might be set via the service's binary_path_name
      #
      # All these parameters then get layered on top of those from Chef::Config

      parse_options # Operates on ARGV by default
      parse_options startup_parameters

      Chef::Log.info("Push Client using default config file path: '#{config[:config_file]}'")

      begin
        case config[:config_file]
        when /^(http|https):\/\//
          begin
            # First we will try Chef::HTTP::SimpleJSON as preference to Chef::REST
            require 'chef/http/simple_json'
            Chef::HTTP::SimpleJSON.new("").streaming_request(config[:config_file]) { |f| apply_config(f.path) }
          rescue LoadError
            require 'chef/rest'
            Chef::REST.new("", nil, nil).fetch(config[:config_file]) { |f| apply_config(f.path) }
          end
        else
          ::File::open(config[:config_file]) { |f| apply_config(f.path) }
        end
      rescue Errno::ENOENT => error
        Chef::Log.warn("*****************************************")
        Chef::Log.warn("Did not find config file: #{config[:config_file]}, using command line options.")
        Chef::Log.warn("*****************************************")

        Chef::Config.merge!(config)
      rescue SocketError => error
        Chef::Application.fatal!("Error getting config file #{Chef::Config[:config_file]}", 2)
      rescue Chef::Exceptions::ConfigurationError => error
        Chef::Application.fatal!("Error processing config file #{Chef::Config[:config_file]} with error #{error.message}", 2)
      rescue Exception => error
        Chef::Application.fatal!("Unknown error processing config file #{Chef::Config[:config_file]} with error #{error.message}", 2)
      end
    end

  end
end

# To run this file as a service, it must be called as a script from within
# the Windows Service framework.  In that case, kick off the main loop!
if __FILE__ == $0
    PushyClient::WindowsService.mainloop
end
