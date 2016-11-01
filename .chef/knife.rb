current_dir = File.expand_path(File.dirname(__FILE__))

chef_server_url "https://api.chef-server.dev/organizations/push-client-local"
log_location STDOUT
ssl_verify_mode :verify_none

node_name "local-dev"
client_key "#{ENV['INSTALLER_PATH'] || "#{ENV['HOME']}/Downloads"}/local-dev.pem"

validation_client_name "push-client-local-validator"
validation_key "#{ENV['INSTALLER_PATH'] || "#{ENV['HOME']}/Downloads"}/push-client-local-validator.pem"
