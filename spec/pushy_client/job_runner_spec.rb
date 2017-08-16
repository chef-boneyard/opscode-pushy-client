require "spec_helper"
require "chef/log"
require "pushy_client/job_runner"

describe PushyClient::JobRunner do
  describe "#start_process" do
    let(:client) { double("client") }
    let(:shellout) { double("shellout") }
    let(:job_runner) { described_class.new(client) }
    let(:whitelist) do
      {
        command => command
      }
    end

    let(:opts) do
      {
        'user' => 'user',
        'dir' => 'dir',
        'env' => {}
      }
    end

    let(:node_name) { 'node-name' }
    let(:command) { 'command' }
    let(:job_id) { 'id' }

    let(:default_hash) do
      {
        'CHEF_PUSH_NODE_NAME' => node_name,
        'CHEF_PUSH_JOB_ID' => job_id
      }
    end

    subject(:start_process) do
      job_runner.instance_variable_set(:@opts, opts)
      job_runner.instance_variable_set(:@command, command)
      job_runner.instance_variable_set(:@job_id, job_id)
      job_runner.send(:start_process)
    end

    before :each do
      allow(client).to receive(:node_name).and_return(node_name)
      allow(client).to receive(:allowed_overwritable_env_vars)
      allow(client).to receive(:whitelist).and_return(whitelist)
      allow(Mixlib::ShellOut).to receive(:new).and_return(shellout)
    end

    context "When allowed_overwriteable_env_vars is nil" do
      it "has only the default env variables if no others are specified" do
        expect(Mixlib::ShellOut).to receive(:new).with(command, hash_including(
          :env=>default_hash)).and_return(shellout)
        start_process
      end

      it "uses the passed env vars" do
        hash = {"foo" => "bar"}
        hash_expected = default_hash.merge(hash)
        opts['env'] = hash

        expect(Mixlib::ShellOut).to receive(:new).with(command, hash_including(
          :env=>hash_expected)).and_return(shellout)
        start_process
      end
    end

    context "When allowed_overwriteable_env_vars is not nil" do
      before do
        allow(client).to receive(:allowed_overwritable_env_vars).and_return(['foo'])
      end

      it "only returns the default env variables if no others are specified" do
        expect(Mixlib::ShellOut).to receive(:new).with(command, hash_including(
          :env=>hash_including(default_hash))).and_return(shellout)
        start_process
      end

      it "uses the passed env vars when it's in the allowed list" do
        hash = {"foo" => "bar"}
        hash_expected = default_hash.merge(hash)
        opts['env'] = hash

        expect(Mixlib::ShellOut).to receive(:new).with(command, hash_including(
          :env=>hash_expected)).and_return(shellout)
        start_process
      end

      it "munges the passed env vars when it's not in the allowed list" do
        hash = {"bar" => "bar"}
        hash_expected = default_hash.merge("CHEF_PUSH_ENV_bar" => "bar")
        opts['env'] = hash

        expect(Mixlib::ShellOut).to receive(:new).with(command, hash_including(
          :env=>hash_expected)).and_return(shellout)
        start_process
      end
    end

  end
end
