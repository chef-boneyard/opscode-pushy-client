execute "terraform get" do
  cwd node['chef-acceptance']['suite-dir']
end

execute "terraform plan" do
  cwd node['chef-acceptance']['suite-dir']
end

execute "terraform apply" do
  cwd node['chef-acceptance']['suite-dir']
end
