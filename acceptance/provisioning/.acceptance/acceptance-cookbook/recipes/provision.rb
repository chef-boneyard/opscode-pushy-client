include_recipe "acceptance-cookbook::default"

with_machine_options bootstrap_options: {
  instance_type: 'm3.medium',
  key_name: 'opscode-pushy-client-acceptance',
  image_id: "ami-7f675e4f"
}

machine_batch do
  machine 'server' do
    run_list ["acceptance-cookbook::_server"]
  end

  machine 'client' do
    run_list ["acceptance-cookbook::_client"]
  end
end
