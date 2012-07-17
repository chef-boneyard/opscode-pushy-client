include 'spec_helper'

class IntegrationHelper

  # Method to start up a new client that will be reaped when
  # the test finishes
  def start_new_client(name)
    @clients = [] if !@clients
    new_client = PushyClient::App.new(
      :service_url_base        => config[:service_url_base],
#      :client_private_key_path => config[:client_private_key_path],
      :node_name               => name
    )
    new_client.start
  end
  after :each do
    if @clients
      @clients.each do |client|
        client.stop
      end
      @clients = nil
    end
  end

end
