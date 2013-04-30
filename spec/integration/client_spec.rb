require 'spec_helper'

describe WinRM::Client do
  before(:all) do
    unless `vagrant status` =~ /running/
      puts "Starting Vagrant..."
      `vagrant up`
    end
  end

  let(:client) { WinRM::Client.new('localhost', user: 'vagrant', pass: 'vagrant') }
  after(:each) { client.disconnect }

  describe '.wql' do
    subject(:response) { client.wql('select * from Win32_Process') }
    it { should be_kind_of(Array) }
    it { response[0].should be_kind_of(Hash) }
  end

  describe '.cmd' do
    subject(:response) { client.cmd('cmd', '/c dir && echo error 1>&2 && exit 0', stdout: StringIO.new, stderr: StringIO.new) }

    it { response[0].should == 0}
    it { response[1].read.should =~ /install-chef\.bat/ }
    it { response[2].read.should =~ /error/ }
  end

  describe '.powershell' do
    subject(:response) { client.powershell('dir; write-error "Error"; exit 0', stdout: StringIO.new, stderr: StringIO.new) }

    it { response[0].should == 0}
    it { response[1].read.should =~ /install-chef\.bat/ }
    it { response[2].read.should =~ /Error/ }
  end
end