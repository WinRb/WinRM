require 'spec_helper'

describe WinRM::Request::Base do
  before(:all) do
    class WinRM::Request::BaseTestObject < WinRM::Request::Base
      attr_accessor :option1
      attr_accessor :option2
      attr_accessor :local_namespaces
    end
  end

  let(:client) do
    WinRM::Client.new('localhost', user: 'vagrant', pass: 'vagrant')
  end

  let(:instance) do 
    WinRM::Request::BaseTestObject.new(client, option1: 'Option 1', option2: 'Option 2')
  end

  let(:namespaces) do
    { "@xmlns:#{WinRM::NS_ADDRESSING}"=>"http://schemas.xmlsoap.org/ws/2004/08/addressing", 
      "@xmlns:#{WinRM::NS_CIMBINDING}"=>"http://schemas.dmtf.org/wbem/wsman/1/cimbinding.xsd", 
      "@xmlns:#{WinRM::NS_ENUM}"=>"http://schemas.xmlsoap.org/ws/2004/09/enumeration", 
      "@xmlns:#{WinRM::NS_TRANSFER}"=>"http://schemas.xmlsoap.org/ws/2004/09/transfer", 
      "@xmlns:#{WinRM::NS_WSMAN_DMTF}"=>"http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd", 
      "@xmlns:#{WinRM::NS_WSMAN_MSFT}"=>"http://schemas.microsoft.com/wbem/wsman/1/wsman.xsd", 
      "@xmlns:#{WinRM::NS_WSMAN_CONF}"=>"http://schemas.microsoft.com/wbem/wsman/1/config", 
      "@xmlns:xsd"=>"http://www.w3.org/2001/XMLSchema", 
      "@xmlns:#{WinRM::NS_SCHEMA_INST}"=>"http://www.w3.org/2001/XMLSchema-instance", 
      "@xmlns:#{WinRM::NS_WIN_SHELL}"=>"http://schemas.microsoft.com/wbem/wsman/1/windows/shell", 
      "@xmlns:#{WinRM::NS_SOAP_ENV}"=>"http://www.w3.org/2003/05/soap-envelope", 
      "@xmlns:#{WinRM::NS_WSMAN_FAULT}"=>"http://schemas.microsoft.com/wbem/wsman/1/wsmanfault" }
  end

  context 'options attr_accessor assignment' do
    subject(:request) { instance }
    it { request.option1.should == 'Option 1' }
    it { request.option2.should == 'Option 2' }
  end
  
  describe '.namespaces_to_attrs' do
    it { instance.namespaces_to_attrs.should == namespaces }

    context 'with local namespaces' do
      subject(:request) do
       instance.local_namespaces = {'xmlns:local' => 'http://example.com/local'}
       instance
      end

      let(:local_namespaces) do
        local_namespaces = namespaces.dup
        local_namespaces['@xmlns:local'] = 'http://example.com/local'
        local_namespaces
      end
      
      it { request.namespaces_to_attrs.should == local_namespaces }
    end
  end

  describe '.selector_set' do
    context 'default options' do
      it { instance.selectors.should == {} }
      it { instance.selector_set.should == {} }
    end

    context 'with a selector set' do
      subject(:request) do
        instance.selectors = { item_key: :item_value }
        instance
      end

      it do 
        request.selector_set.should == { "w:SelectorSet" =>
                                        [{"w:Selector"=> { 
                                            :content! => :item_value, 
                                            :@Name=>:item_key}
                                        }]
                                    }
      end
    end
  end

  describe 'un-implemented methods' do
    %w{body header to_s}.each do |method|
      describe method do
        it { expect { instance.send(method) }.to raise_error(StandardError) }
      end
    end
  end

  describe '.to_s' do
    before do 
      instance.stub(:body) { {} }
      instance.stub(:header) { instance.base_headers }
    end

    subject(:message) { Nokogiri::XML(instance.to_s) }
    
    describe 'namespaces' do
      it 'has only valid namespaces' do
        message =  Nokogiri::XML(instance.to_s)
        message.collect_namespaces.each do |k,v|
            namespaces["@#{k}"].should == v
        end
      end
    end

    describe 'body' do
      it { message.xpath("/#{WinRM::NS_SOAP_ENV}:Envelope/#{WinRM::NS_SOAP_ENV}:Body").children.count.should == 0 }
    end
  end
end