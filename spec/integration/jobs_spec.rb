require 'spec_helper'
require 'pushy-client'
require 'chef/rest'


describe PushyClient::App do

  # Method to start up a new client that will be reaped when
  # the test finishes
  def start_new_client(name)
    new_client = PushyClient::App.new(
      :service_url_base        => TestConfig.service_url_base,
      :client_private_key_path => TestConfig.client_private_key_path,
      :node_name               => name
    )

    new_client_thread = Thread.new do
      new_client.start
    end
    # Wait until clients are registered with the server
    # TODO check for timeout and failure here
    until new_client.worker
      sleep 0.02
    end
    # Register for state changes
    new_client_states = [ new_client.worker.state ]
    new_client.worker.on_state_change = Proc.new { |state| new_client_states << new_client.worker.state }
    until new_client.worker.monitor.online?
      sleep 0.02
    end
    @clients = [] if !@clients
    @clients << {
      :client => new_client,
      :thread => new_client_thread,
      :states => new_client_states
    }
  end
  after :each do
    if @clients
      @clients.each do |client|
        if client[:client].worker
          client[:client].stop
        end
        client[:thread].kill
      end
      @clients = nil
    end
  end

  let(:rest) do
    # No auth yet
    Chef::REST.new(TestConfig.service_url_base, false, false)
  end

  context 'with one client', :focus do
    before :each do
      start_new_client('DERPY')
    end

    context 'when running chef-client' do
      before(:each) do
        @response = rest.post_rest("pushy/jobs", {
          'command' => 'echo YAHOO',
          'nodes' => @clients.map { |c| c[:client].node_name }
        })
        # Wait until all have run
        until @clients.all? { |client| client[:states].include?('running') && client[:client].worker.state == 'idle' }
          sleep(0.02)
        end
      end

      it 'is marked complete' do
        job = nil
        begin
          sleep(0.02) if job
          job = rest.get_rest(@response['uri'])
        end until job['status'] == 'complete'
        job.delete('id')
        job.delete('created_at')
        job.delete('updated_at')
        job.should == {
          'command' => 'echo YAHOO',
          'duration' => 300,
          'nodes' => { 'complete' => ['DERPY'] },
          'status' => 'complete'
        }
      end
    end
  end
end
