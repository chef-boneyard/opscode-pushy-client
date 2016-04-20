include_recipe "acceptance-cookbook::default"

machine_batch do
  action :destroy
  machines 'server', 'client'
end
