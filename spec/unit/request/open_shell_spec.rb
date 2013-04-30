require 'spec_helper'

describe WinRM::Request::OpenShell do

 let(:client) do
    WinRM::Client.new('localhost', user: 'vagrant', pass: 'vagrant')
  end



  context 'intialized with defaults' do
    let(:request) do
      WinRM::Request::OpenShell.new(client)
    end

    it { request.codepage.should == 437 } 
    it { request.noprofile.should == false }
    it { request.input_stream.should == 'stdin' }
    it { request.output_streams.should == 'stdout stderr' }

    subject(:message) { Nokogiri::XML(request.to_s) }

    it_should_behave_like "a WinRM request" do
      let(:resource_uri) { 'http://schemas.microsoft.com/wbem/wsman/1/windows/shell/cmd' }
      let(:action) { 'http://schemas.xmlsoap.org/ws/2004/09/transfer/Create' }
    end

    it_should_behave_like "a WinRM option set" do
      let(:option_set) { {WINRS_CODEPAGE: request.codepage.to_s, WINRS_NOPROFILE: request.noprofile.to_s.upcase}}
    end

    describe '.to_s' do
      context 'body' do
        describe 'Input Streams' do
          it { message.xpath("/#{WinRM::NS_SOAP_ENV}:Envelope/#{WinRM::NS_SOAP_ENV}:Body/#{WinRM::NS_WIN_SHELL}:Shell/#{WinRM::NS_WIN_SHELL}:InputStreams").text.should == 'stdin' }
        end 
        describe 'Output Streams' do
          it { message.xpath("/#{WinRM::NS_SOAP_ENV}:Envelope/#{WinRM::NS_SOAP_ENV}:Body/#{WinRM::NS_WIN_SHELL}:Shell/#{WinRM::NS_WIN_SHELL}:OutputStreams").text.should == 'stdout stderr' }
        end
      end
    end

    describe '.execute' do
      before(:each) do
        client.stub(:send_message).and_return do
          File.read('spec/mock/open_shell.xml')
        end
      end

      it { request.execute.should == "62DE33F0-8674-43D9-B6A5-3298012CC4CD"}
    end
  end

  context 'initialized with options' do
    let(:request) do
      WinRM::Request::OpenShell.new(client, codepage: 123, noprofile: true, input_stream: 'fake', output_streams: 'fake fake')
    end

    it { request.codepage.should == 123 }
    it { request.noprofile.should == true }
    it { request.input_stream.should == 'fake' }
    it { request.output_streams.should == 'fake fake'}

    describe '.to_s' do
      subject(:message) { Nokogiri::XML(request.to_s) }
      it_should_behave_like "a WinRM request" do
        let(:resource_uri) { 'http://schemas.microsoft.com/wbem/wsman/1/windows/shell/cmd' }
        let(:action) { 'http://schemas.xmlsoap.org/ws/2004/09/transfer/Create' }
      end

      it_should_behave_like "a WinRM option set" do
        let(:option_set) { {WINRS_CODEPAGE: request.codepage.to_s, WINRS_NOPROFILE: request.noprofile.to_s.upcase}}
      end

      context 'body' do
        describe 'Input Streams' do 
          it { message.xpath("/#{WinRM::NS_SOAP_ENV}:Envelope/#{WinRM::NS_SOAP_ENV}:Body/#{WinRM::NS_WIN_SHELL}:Shell/#{WinRM::NS_WIN_SHELL}:InputStreams").text.should == 'fake' }
        end
        describe 'Output Streams' do 
          it { message.xpath("/#{WinRM::NS_SOAP_ENV}:Envelope/#{WinRM::NS_SOAP_ENV}:Body/#{WinRM::NS_WIN_SHELL}:Shell/#{WinRM::NS_WIN_SHELL}:OutputStreams").text.should == 'fake fake' }
        end
      end
    end
  end

  context 'with environmental variables variables' do
    let(:request) do
      WinRM::Request::OpenShell.new(client, codepage: 123, noprofile: true, input_stream: 'fake', output_streams: 'fake fake', env_vars: {var1: :value1})
    end
    
    describe '.to_s' do
      subject(:message) { Nokogiri::XML(request.to_s) }

      it_should_behave_like "a WinRM request" do
        let(:resource_uri) { 'http://schemas.microsoft.com/wbem/wsman/1/windows/shell/cmd' }
        let(:action) { 'http://schemas.xmlsoap.org/ws/2004/09/transfer/Create' }
      end

      it_should_behave_like "a WinRM option set" do
        let(:option_set) { {WINRS_CODEPAGE: request.codepage.to_s, WINRS_NOPROFILE: request.noprofile.to_s.upcase}}
      end

      context 'body' do
        describe 'Environmental Variables' do
          it { message.xpath("/#{WinRM::NS_SOAP_ENV}:Envelope/#{WinRM::NS_SOAP_ENV}:Body/#{WinRM::NS_WIN_SHELL}:Shell/#{WinRM::NS_WIN_SHELL}:Environment/#{WinRM::NS_WIN_SHELL}:Variable[@Name='var1']").text.should == 'value1' }
        end
      end
    end
  end

  context 'with working directory' do
    let(:request) do
      WinRM::Request::OpenShell.new(client, codepage: 123, noprofile: true, input_stream: 'fake', output_streams: 'fake fake', working_directory: "C:\\temp")
    end

    describe '.to_s' do
      subject(:message) { Nokogiri::XML(request.to_s) }

      it_should_behave_like "a WinRM request" do
        let(:resource_uri) { 'http://schemas.microsoft.com/wbem/wsman/1/windows/shell/cmd' }
        let(:action) { 'http://schemas.xmlsoap.org/ws/2004/09/transfer/Create' }
      end

      it_should_behave_like "a WinRM option set" do
        let(:option_set) { {WINRS_CODEPAGE: request.codepage.to_s, WINRS_NOPROFILE: request.noprofile.to_s.upcase}}
      end

      context 'body' do
        describe 'Working Directory' do
          it { message.xpath("/#{WinRM::NS_SOAP_ENV}:Envelope/#{WinRM::NS_SOAP_ENV}:Body/#{WinRM::NS_WIN_SHELL}:Shell/#{WinRM::NS_WIN_SHELL}:WorkingDirectory").text == "C:\\Temp" }
        end
      end
    end
  end
  

end
