require 'chef/provisioning/aws_driver'

with_driver 'aws::us-west-2'

aws_key_pair 'opscode-pushy-client-acceptance' do
  private_key_options({
    :format => :pem,
    :type => :rsa,
    :regenerate_if_different => true
  })
  allow_overwrite true
end
