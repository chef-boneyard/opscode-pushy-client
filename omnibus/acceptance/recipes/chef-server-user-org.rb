chef_server_user 'acceptance' do
  firstname 'Example'
  lastname 'User'
  email 'acceptance@push-jobs.test'
  password 'password'
  private_key_path '/tmp/acceptance/.chef/acceptance.pem'
  action :create
end

chef_server_org 'example' do
  org_long_name 'Example Organization'
  org_private_key_path '/tmp/acceptance/.chef/example.pem'
  action :create
end

chef_server_org 'example' do
  admins %w( acceptance )
  action :add_admin
end

execute "knife ssl fetch https://192.168.33.30"

execute "create-client" do
  command "knife client create push-client --disable-editing -c /tmp/acceptance/.chef/knife.rb > /tmp/acceptance/.chef/push-client.pem"
  not_if "knife client list | grep push-client"
end
#
# execute "create-node" do
#   command "knife node create push-client -c /tmp/acceptance/.chef/knife.rb"
#   action :nothing
# end
