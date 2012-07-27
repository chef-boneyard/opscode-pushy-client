require 'spec_helper'
require 'pushy-client'
require 'chef/rest'
require 'timeout'


describe PushyClient::App do

  # Method to start up a new client that will be reaped when
  # the test finishes
  def start_new_clients(*names)
    @clients = {} if !@clients
    names.each do |name|
      raise "Client #{name} already created" if @clients[name]
      @clients[name] = {
        :states => []
      }
    end

    start_clients(*names)
  end

  def start_client(name)
    start_clients(name)
  end

  def start_clients(*names)
    names.each do |name|
      raise "Client #{name} already started" if @clients[name][:client]

      new_client = PushyClient::App.new(
        :service_url_base        => TestConfig.service_url_base,
        :client_private_key_path => TestConfig.client_private_key_path,
        :node_name               => name
      )
      @clients[name][:client] = new_client

      # If we already have a thread, call start here--it will piggyback on the
      # main event loop.
      if @thread
        new_client.start
      else
        @thread = Thread.new do
          new_client.start
        end
      end
    end

    # Wait until client is registered with the server
    Timeout::timeout(5) do
      until names.all? { |name| @clients[name][:client].worker }
        sleep 0.2
      end
    end

    names.each do |name|
      client =  @clients[name]

      # Register for state changes
      worker = client[:client].worker
      client[:states] << worker.state
      worker.on_state_change = Proc.new { |state| client[:states] << worker.state }
    end

    Timeout::timeout(5) do
      until names.all? { |name| @clients[name][:client].worker.monitor.online? }
        sleep 0.02
      end
    end
  end

  def stop_client(name)
    client = @clients[name][:client]
    @clients[name][:client] = nil

    raise "Client #{name} already stopped" if !client

    client.stop if client.worker

    # If there are no more clients, kill the EM thread (the first thread
    # that a client has ever run on)
    if !@clients.values.any? { |c| c[:client] }
      EM.run { EM.stop_event_loop }
      if !@thread.join(1)
        puts "Timed out stopping client #{name}.  Killing thread."
        @thread.kill
        @thread = nil
      end
#      begin
#        Timeout::timeout(1) do
#          until client.worker.state == 'restarting'
#            sleep(0.02)
#          end
#        end
#      rescue Timeout::Error
#        puts "Timed out stopping client #{name}.  Killing thread."
#        thread.kill
#      end
    end
  end

  after :each do
    if @clients
      @clients.each do |client_name, client|
        puts "Stopping #{client_name} ..."
        stop_client(client_name)
        puts "Stopped #{client_name}."
      end
      @clients = nil
    end
  end

  def wait_for_job_complete(uri)
    job = nil
    begin
      sleep(0.02) if job
      job = rest.get_rest(uri)
    end until job['status'] == 'complete'
    job.delete('id')
    job.delete('created_at')
    job.delete('updated_at')
    job
  end

  def run_job_on_all_clients
    @response = rest.post_rest("pushy/jobs", {
      'command' => 'echo YAHOO',
      'nodes' => @clients.keys
    })
    # Wait until all have run
    until @clients.values.all? { |client| client[:states].include?('running') && client[:client].worker.state == 'idle' }
      sleep(0.02)
    end
  end

  def job_should_complete_on_all_clients
    clients = @clients.keys.sort
    job = wait_for_job_complete(@response['uri'])
    job['nodes']['complete'] = job['nodes']['complete'].sort
    job.should == {
      'command' => 'echo YAHOO',
      'duration' => 300,
      'nodes' => { 'complete' => clients },
      'status' => 'complete'
    }
  end

  # Begin tests
  let(:rest) do
    # No auth yet
    Chef::REST.new(TestConfig.service_url_base, false, false)
  end

  context 'with one client' do
    before :each do
      start_new_clients('DONKEY')
    end

    context 'when running a job' do
      before(:each) do
        run_job_on_all_clients
      end

      it 'is marked complete' do
        job_should_complete_on_all_clients
      end
    end
  end

  context 'with three clients' do
    before :each do
      start_new_clients('DONKEY', 'FARQUAD', 'FIONA')
    end

    context 'when running a job' do
      before(:each) do
        run_job_on_all_clients
      end

      it 'the job and node statuses are marked complete' do
        job_should_complete_on_all_clients
      end
    end
  end
end
