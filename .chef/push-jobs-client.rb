current_dir = File.expand_path(File.dirname(__FILE__))

chef_server_url "https://api.chef-server.dev/organizations/push-client-local"
log_location STDOUT
ssl_verify_mode :verify_none

node_name "push-client-dev-local"
client_key "#{current_dir}/push-client-dev-local.pem"

trusted_certs_dir "#{current_dir}/trusted_certs"
whitelist {

}
