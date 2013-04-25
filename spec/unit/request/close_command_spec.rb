require 'spec_helper'

describe WinRM::Request::CloseCommand do

 let(:client) do
    WinRM::Client.new('localhost', user: 'vagrant', pass: 'vagrant')
  end

  let(:request) do
    WinRM::Request::CloseCommand.new(client, shell_id: 123, command_id: 1234)
  end

  subject(:message) { Nokogiri::XML(request.to_s) }

  it_should_behave_like "a WinRM request" do
    let(:resource_uri) { 'http://schemas.microsoft.com/wbem/wsman/1/windows/shell/cmd' }
    let(:action) { 'http://schemas.microsoft.com/wbem/wsman/1/windows/shell/Signal' }
  end

  it_should_behave_like "a WinRM selector set" do
    let(:selectors) { { ShellId: "123" } }
  end

  describe '.to_s' do
    context 'body' do
      it { message.xpath("/#{WinRM::NS_SOAP_ENV}:Envelope/#{WinRM::NS_SOAP_ENV}:Body/#{WinRM::NS_WIN_SHELL}:Signal/#{WinRM::NS_WIN_SHELL}:Code").text.should == "http://schemas.microsoft.com/wbem/wsman/1/windows/shell/signal/terminate" }
      it { message.xpath("/#{WinRM::NS_SOAP_ENV}:Envelope/#{WinRM::NS_SOAP_ENV}:Body/#{WinRM::NS_WIN_SHELL}:Signal[@CommandId='1234']").text.should == "http://schemas.microsoft.com/wbem/wsman/1/windows/shell/signal/terminate" }

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