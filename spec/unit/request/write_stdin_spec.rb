require 'spec_helper'

describe WinRM::Request::WriteStdin do

 let(:client) do
    WinRM::Client.new('localhost', user: 'vagrant', pass: 'vagrant')
  end

  let(:request) do
    WinRM::Request::WriteStdin.new(client, shell_id: 123, command_id: 123, text: 'test command')
  end

  subject(:message) { Nokogiri::XML(request.to_s) }

  it_should_behave_like "a WinRM request" do
    let(:resource_uri) { 'http://schemas.microsoft.com/wbem/wsman/1/windows/shell/cmd' }
    let(:action) { 'http://schemas.microsoft.com/wbem/wsman/1/windows/shell/Send' }
  end

  it_should_behave_like "a WinRM selector set" do
    let(:selectors) { { ShellId: "123" } }
  end

  describe '.to_s' do
    describe 'body' do
      describe 'command text' do
        it { message.xpath("/#{WinRM::NS_SOAP_ENV}:Envelope/#{WinRM::NS_SOAP_ENV}:Body/#{WinRM::NS_WIN_SHELL}:Send/#{WinRM::NS_WIN_SHELL}:Stream").text.should == "dGVzdCBjb21tYW5k\n"}
      end
      describe 'stream name' do
        it { message.xpath("/#{WinRM::NS_SOAP_ENV}:Envelope/#{WinRM::NS_SOAP_ENV}:Body/#{WinRM::NS_WIN_SHELL}:Send/#{WinRM::NS_WIN_SHELL}:Stream")[0].attributes["Name"].value == "stdin"}
      end
      describe 'command id' do
        it { message.xpath("/#{WinRM::NS_SOAP_ENV}:Envelope/#{WinRM::NS_SOAP_ENV}:Body/#{WinRM::NS_WIN_SHELL}:Send/#{WinRM::NS_WIN_SHELL}:Stream")[0].attributes["CommandId"].value == "123"}
      end
    end
  end

  describe '.execute' do
    before { request.client.stub(:send_message) { true } }
    it 'sends a message' do
      request.client.should_receive(:send_message)
      request.execute.should == true
    end
  end
  

end