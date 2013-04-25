require 'spec_helper'

describe WinRM::Request::OpenShell do

 let(:client) do
    WinRM::Client.new('localhost', user: 'vagrant', pass: 'vagrant')
  end

  let(:request) do
    WinRM::Request::CloseShell.new(client, shell_id: 123)
  end

  subject(:message) { Nokogiri::XML(request.to_s) }

  it_should_behave_like "a WinRM request" do
    let(:resource_uri) { 'http://schemas.microsoft.com/wbem/wsman/1/windows/shell/cmd' }
    let(:action) { 'http://schemas.xmlsoap.org/ws/2004/09/transfer/Delete' }
  end

  it_should_behave_like "a WinRM selector set" do
    let(:selectors) { { ShellId: "123" } }
  end

  describe '.execute' do
    before { request.client.stub(:send_message) { true } }
    it 'sends a message' do
      request.client.should_receive(:send_message)
      request.execute.should == true
    end
  end
  

end