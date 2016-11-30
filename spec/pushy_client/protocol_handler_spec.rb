require "spec_helper"
require "chef/log"
require "pushy_client/protocol_handler"

describe PushyClient::ProtocolHandler do
  describe "#send_command" do
    let(:client) { double("client") }
    let(:protocol_handler) { described_class.new(client) }
    let(:params) { {} }

    subject(:send_command) do
      protocol_handler.send_command(:succeeded, 0, params)
    end

    before :each do
      allow(client).to receive(:on_server_availability_change)
      allow(client).to receive(:node_name)
      allow(client).to receive(:hostname)
      allow(client).to receive(:org_name)
      allow(client).to receive(:incarnation_id)
      allow_any_instance_of(described_class).to receive(:send_signed_json_command)
      allow(Chef::Log).to receive(:warn)
    end

    context "when the message exceeds the MAX_BODY_SIZE" do
      let(:params) do
        {
          stdout: Array.new(32000, "x").join,
          stderr: Array.new(32000, "x").join,
        }
      end

      it "logs a warning" do
        expect(Chef::Log).to receive(:warn).with(
          "Command output too long. Will not be sent to server."
        )
        send_command
      end

      it "drops stderr and stdout" do
        expect(protocol_handler).to receive(:send_signed_json_command).with(
          :hmac_sha256, hash_excluding(:stdout, :stderr)
        )
        send_command
      end
    end
  end
end
