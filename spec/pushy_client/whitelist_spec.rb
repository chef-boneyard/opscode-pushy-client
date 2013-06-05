require 'spec_helper'
require 'pushy_client/whitelist'

describe PushyClient::Whitelist do
  let(:whitelist) do
    {
      "chef-client" => "chef-client",
      /^deliverance (.+)$/ => 'deliverance eats at \1',
      /^hard (.+)$/ => {
        :lock => true,
        :command_line => 'tastes like \1'
      }
    }
  end

  let(:pcw) do
    PushyClient::Whitelist.new(whitelist)
  end

  describe "initialize" do
    it "takes a whitelist hash and stores it in an instance attr" do
      pcw = PushyClient::Whitelist.new(whitelist)
      expect(pcw.whitelist).to eq(whitelist)
    end
  end

  describe "[]" do
    let(:pcw) do
      PushyClient::Whitelist.new(whitelist)
    end

    it "returns the exact match if it has one" do
      expect(pcw["chef-client"]).to eq("chef-client")
    end

    describe "evaluates regular expressions if no exact match" do
      describe "and the value is a string" do
        it "evaluates regular expression, returning the value string gsub-ed" do
          expect(pcw["deliverance lunchtime"]).to eq("deliverance eats at lunchtime")
        end
      end

      describe "and the value is a hash" do
        it "evaluates the regular expression, returning the hash with command_line entry gsub-ed" do
          expect(pcw["hard chicken"]).to eq({ :lock => true, :command_line => "tastes like chicken"})
        end
      end

      it "skips non-matching keys" do
        expect(pcw["you do not match"]).to eq(nil)
      end
    end
  end

  describe "works for regular hash methods" do
    it "supports non-block methods" do
      expect(pcw.keys).to eq(whitelist.keys)
    end

    it "supports block methods" do
      seen = {}
      pcw.each do |key, value|
        seen[key] = value
      end
      expect(pcw.whitelist).to eq(seen)
    end
  end


end
