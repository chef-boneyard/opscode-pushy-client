current_dir = File.dirname(__FILE__)
log_location             STDOUT
node_name                "acceptance"
client_key               "#{current_dir}/acceptance.pem"
validation_client_name   "example_validator"
validation_key           "#{current_dir}/example_validator.pem"
chef_server_url          "https://192.168.33.30/organizations/example"
cache_type               'BasicFile'
cache_options( :path => "#{ENV['HOME']}/.chef/checksums" )
ssl_verify_mode          :verify_none
