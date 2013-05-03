require 'spec_helper'

describe WinRM::Client do
  context 'with no username and password' do
    it { expect { WinRM::Client.new('localhost') }.to raise_error(StandardError,'Username and Password are required') }
  end

  let(:client) { WinRM::Client.new('localhost', user: 'vagrant', pass: 'vagrant') }

  describe 'authentication stack' do
    subject(:auth) { client.httpcli.www_auth.instance_variable_get("@authenticator") }
    it { auth.count.should be(2) }
    it { auth[0].should be(client.httpcli.www_auth.negotiate_auth) }
    it { auth[1].should be(client.httpcli.www_auth.sspi_negotiate_auth) }
  end
  describe '.ready?' do
    context 'not ready' do
      before(:each) do
        client.stub(:wql).and_raise(HTTPClient::KeepAliveDisconnected)
      end

      it { client.ready?.should == false }
    end
    context 'ready' do
      before(:each) do
        client.stub(:wql).and_return(true)
      end

      it { client.ready?.should == true }
    end
  end

  describe '.wql' do
    before(:each) do
      client.stub(:send_message).and_return do 
        @request_number ||= 1
        case @request_number
        when 1
          response = File.read('spec/mock/enumerate_1.xml')
          @request_number += 1
        when 2
          response = File.read('spec/mock/enumerate_2.xml')
          @request_number += 1
        end
        response
      end
    end

    it { client.wql('select * from Win32_Process').should be_kind_of(Array) }
    it { client.wql('select * from Win32_Process')[0].should be_kind_of(Hash) }
  end

  describe '.shell_id' do
    before(:each) do
      client.stub(:send_message).and_return do
        File.read('spec/mock/open_shell.xml')
      end
    end
    it {client.shell_id.should == "62DE33F0-8674-43D9-B6A5-3298012CC4CD"}
  end

  describe '.cmd' do
    context 'with a block' do
      before(:each) do
        client.stub(:send_message).and_return do
          @request_number ||= 1
          response = File.read("spec/mock/client/cmd/#{@request_number}.xml")
          @request_number += 1
          response
        end
      end
      let(:response) do
        stdout = ''
        stderr = ''
        exit_code = client.cmd('cmd', '/c dir && exit 0') do |stream,text|
          case stream
          when :stderr
            stderr << text
          when :stdout
            stdout << text
          end 
        end
        return exit_code, stdout, stderr
      end

      it { response[0].should == [0, nil]}
      it { response[1].should =~ /9,811,701,760/ }
      it { response[2].should == " Volume in drive C is Windows 2008R2\r\n" }
    end

    context 'without a block' do
      before(:each) do
        client.stub(:send_message).and_return do
          @request_number ||= 1
          response = File.read("spec/mock/client/cmd/#{@request_number}.xml")
          @request_number += 1
          response
        end
      end
      let(:response) do
        exit_code, streams = client.cmd('cmd', '/c dir && exit 0') 
        return exit_code, streams 
      end

      it { response[0][0].should == 0}
      it { response[1][2][:stdout].should =~ /9,811,701,760/ }
      it { response[1][0].should == {:stderr=>" Volume in drive C is Windows 2008R2\r\n"} }
    end

  end

  describe '.powershell' do
    context 'with a block' do
      before(:each) do
        client.stub(:send_message).and_return do
          @request_number ||= 1
          response = File.read("spec/mock/client/powershell/#{@request_number}.xml")
          @request_number += 1
          response
        end
      end

      let(:response) do
        stdout = ''
        stderr = ''
        exit_code = client.powershell('dir') do |stream,text|
          case stream
          when :stderr
            stderr << text
          when :stdout
            stdout << text
          end 
        end
        return exit_code, stdout, stderr
      end

      it { response[0].should == [0, nil]}
      it { response[1].should =~ /150 install-chef.bat/ }
      it { response[2].should =~ /LastWriteTime/ }
    end

    context 'without a block' do
      before(:each) do
        client.stub(:send_message).and_return do
          @request_number ||= 1
          response = File.read("spec/mock/client/powershell/#{@request_number}.xml")
          @request_number += 1
          response
        end
      end
      let(:response) do
        exit_code, streams = client.powershell('dir')
        return exit_code, streams 
      end

      it { response[0][0].should == 0}
      it { response[1][3][:stdout].should =~ /Pictures/ }
      it { response[1][2][:stderr].should =~ /LastWriteTime/ }
    end
  end

  describe '.disconnect' do
    before(:each) do
      client.stub(:send_message).and_return do
        @request_number ||= 1
        response = File.read("spec/mock/client/disconnect/#{@request_number}.xml")
        @request_number += 1
        response
      end
    end

    it { client.disconnect.should == true }
  end

  describe '.send_message' do
    let(:message) { File.read('spec/mock/start_process_1.xml') }
    context 'bad http stats' do
      before(:each) do
        client.httpcli.stub(:post).and_return {  OpenStruct.new(status: 500, http_body: (OpenStruct.new(:content => ''))) }
      end
      it { expect { client.send_message(message) }.to raise_error(WinRM::WinRMHTTPTransportError, "Bad HTTP response returned from server (500).") }
    end

    context 'good http stats' do
      before(:each) do
        client.httpcli.stub(:post).and_return {  OpenStruct.new(status: 200, http_body: (OpenStruct.new(:content => message))) }
      end
      it { client.send_message(message) == message }
    end
  end
end
