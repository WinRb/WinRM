require 'spec_helper'

describe WinRM::Request::StartProcess do

 let(:client) do
    WinRM::Client.new('localhost', user: 'vagrant', pass: 'vagrant')
  end

  let(:command) { 'dir'}

  let(:request) do
    WinRM::Request::StartProcess.new(client, shell_id: 123, command: command)
  end

  subject(:message) { Nokogiri::XML(request.to_s) }

  it_should_behave_like "a WinRM request" do
    let(:resource_uri) { 'http://schemas.microsoft.com/wbem/wsman/1/windows/shell/cmd' }
    let(:action) { 'http://schemas.microsoft.com/wbem/wsman/1/windows/shell/Command' }
  end

  it_should_behave_like "a WinRM selector set" do
    let(:selectors) { { ShellId: "123" } }
  end

  it_should_behave_like "a WinRM option set" do
    let(:option_set) { {WINRS_CONSOLEMODE_STDIN: request.batch_mode.to_s.upcase, WINRS_SKIP_CMD_SHELL: request.skip_command_shell.to_s.upcase}}
  end

  describe '.to_s' do
    context 'body' do
      it { message.xpath("/#{WinRM::NS_SOAP_ENV}:Envelope/#{WinRM::NS_SOAP_ENV}:Body/#{WinRM::NS_WIN_SHELL}:CommandLine/#{WinRM::NS_WIN_SHELL}:Command").text.should == "\"#{command}\"" }
      it { message.xpath("/#{WinRM::NS_SOAP_ENV}:Envelope/#{WinRM::NS_SOAP_ENV}:Body/#{WinRM::NS_WIN_SHELL}:CommandLine/#{WinRM::NS_WIN_SHELL}:Arguments").count.should == 0 }

    end
  end

  describe '.execute' do 
    let(:stream) { StringIO.new }

    before(:each) do 
      client.stub(:send_message).and_return do 
        File.read('spec/mock/start_process_1.xml')
      end
    end
    it { request.execute.should == "35CE9B86-3E89-4AA6-9768-D7EDBF34BCD0" }
   end

end

