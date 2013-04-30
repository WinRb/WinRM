require 'spec_helper'

describe WinRM::FileManager do
  before(:all) do
    unless `vagrant status` =~ /running/
      puts "Starting Vagrant..."
      `vagrant up`
    end
  end

  let(:client) { WinRM::Client.new('localhost', user: 'vagrant', pass: 'vagrant') }
  after(:each) { client.disconnect }
  subject(:fm) { WinRM::FileManager.new(client) }

  describe '.directory?' do
    it { fm.directory?("C:/Windows").should be(true) }
    it { fm.directory?("C:/DoesNotExist").should be(false) }
  end

  describe '.exists?' do
    it { fm.exists?("C:/Windows").should be(true) }
    it { fm.exists?("C:/DoesNotExist").should be(false) }
  end
  describe '.dir' do
    it { fm.dir("C:/windows").should be_kind_of(Array) }
    it { fm.dir("C:/windows")[0].should be_kind_of(Hash) }
    it { expect { fm.dir("C:/DoesNotExits")}.to raise_error(IOError) }
  end

  describe '.send_file' do
    let(:file) { 'README.md'}
    context 'does not exist' do
      before(:each) do
        fm.delete('C:/test_file') if fm.exists?('C:/test_File')
      end
      it { fm.exists?('C:/test_File').should == false}
      it { fm.send_file(file,'C:/test_file').should == true }
    end
    context 'does exist' do
      before(:each) do
        fm.send_file(file,'C:/test_file',overwrite: true)
      end
      it { fm.exists?('C:/test_file').should == true }
      it { expect { fm.send_file(file,'C:/test_file') }.to raise_error(StandardError,'File exists and you did not specify the overwrite option C:/test_file') }
      it { fm.send_file(file,'C:/test_file', overwrite: true).should == true }
    end
  end

  describe '.delete' do
    let(:file) { 'README.md'}
    context 'does not exist' do
      before(:each) do
        fm.delete('C:/test_file') if fm.exists?('C:/test_File')
      end
      it {fm.exists?('C:/test_file').should == false}
      it { expect { fm.delete('C:/test_file')  }.to raise_error(IOError,'Item does not exist C:\test_file')  }
    end
    context 'does exist' do
      before(:each) do
        fm.send_file(file,'C:/test_file',overwrite: true)
      end
      it { fm.exists?('C:/test_file').should == true}
      it { fm.delete('C:/test_file').should == true }
    end
    
  end
end