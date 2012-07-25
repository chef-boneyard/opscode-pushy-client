require "spec_helper"

require 'pushy-client'

describe PushyClient::Client do
  include SpecHelpers::Config

  describe '.from_json' do
    let(:pushy_client) { PushyClient::Client.from_json(config_json) }

    def self.its(_attribute, &expectation)
      context "with configuration attribute :#{_attribute}" do
        subject { pushy_client.send(_attribute) }
        it('should set attribute', &expectation)
      end
    end

    its(:node_name)   { should eql host }
    its(:out_address) { should eql out_addr }
    its(:interval)    { should eql interval }

    its(:offline_threshold) { should eql offline_threshold }
    its(:online_threshold)  { should eql online_threshold }
    its(:lifetime)          { should eql lifetime }

    its(:server_public_key)  { should eql public_key }
  end
end
