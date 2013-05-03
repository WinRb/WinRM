require 'spec_helper'

describe WinRM::Request::ReadOutputStreams do

 let(:client) do
    WinRM::Client.new('localhost', user: 'vagrant', pass: 'vagrant')
  end

  let(:request) do
    WinRM::Request::ReadOutputStreams.new(client, shell_id: 123)
  end

  subject(:message) { Nokogiri::XML(request.to_s) }

  it_should_behave_like "a WinRM request" do
    let(:resource_uri) { 'http://schemas.microsoft.com/wbem/wsman/1/windows/shell/cmd' }
    let(:action) { 'http://schemas.microsoft.com/wbem/wsman/1/windows/shell/Receive' }
  end

  it_should_behave_like "a WinRM selector set" do
    let(:selectors) { { ShellId: "123" } }
  end

  describe '.execute' do
    let(:stream) do
      stdout = ''
      stderr = ''
      request.execute do |stream, text|
          case stream
          when :stdout
            stdout << text
          when :stderr
            stderr << text
          end
      end
      return stdout,stderr
    end

    before(:each) do 
      client.stub(:send_message).and_return do 
        File.read('spec/mock/read_output_streams.xml')
      end
    end

    it { stream[1].should =~ /install-chef.bat/ }
    it { stream[0].should =~ /Pictures/ }
    it { stream[0].should =~ /Music/ }
  end
  

end