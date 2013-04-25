require 'spec_helper'

describe WinRM::Request::Wql do

 let(:client) do
    WinRM::Client.new('localhost', user: 'vagrant', pass: 'vagrant')
  end

  let(:request) do
    WinRM::Request::Wql.new(client, query: 'select * from Win32_Process')
  end

  subject(:message) { Nokogiri::XML(request.to_s) }

  it_should_behave_like "a WinRM request" do
    let(:resource_uri) { 'http://schemas.microsoft.com/wbem/wsman/1/wmi/root/cimv2/*' }
    let(:action) { 'http://schemas.xmlsoap.org/ws/2004/09/enumeration/Enumerate' }
  end
  describe '.to_s' do
    context 'body' do
      it { message.xpath("/#{WinRM::NS_SOAP_ENV}:Envelope/#{WinRM::NS_SOAP_ENV}:Body/#{WinRM::NS_ENUM}:Enumerate/#{WinRM::NS_WSMAN_DMTF}:OptimizeEnumeration").text.should == '' }
      it { message.xpath("/#{WinRM::NS_SOAP_ENV}:Envelope/#{WinRM::NS_SOAP_ENV}:Body/#{WinRM::NS_ENUM}:Enumerate/#{WinRM::NS_WSMAN_DMTF}:MaxElements").text.should == request.max_elements.to_s }
      it { message.xpath("/#{WinRM::NS_SOAP_ENV}:Envelope/#{WinRM::NS_SOAP_ENV}:Body/#{WinRM::NS_ENUM}:Enumerate/#{WinRM::NS_WSMAN_DMTF}:Filter").text.should == request.query }
    end
  end
end