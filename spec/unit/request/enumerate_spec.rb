require 'spec_helper'

describe WinRM::Request::Enumerate do

 let(:client) do
    WinRM::Client.new('localhost', user: 'vagrant', pass: 'vagrant')
  end

  let(:wql) do
    WinRM::Request::Wql.new(client, query: 'select * from Win32_Process')
  end

  let(:request) do
    WinRM::Request::Enumerate.new(client, resource_uri: wql.resource_uri, context: 1234)
  end



  subject(:message) { Nokogiri::XML(request.to_s) }

  it_should_behave_like "a WinRM request" do
    let(:resource_uri) { "http://schemas.microsoft.com/wbem/wsman/1/wmi/root/cimv2/*" }
    let(:action) { 'http://schemas.xmlsoap.org/ws/2004/09/enumeration/Pull' }
  end
  describe '.to_s' do
    context 'body' do
      it { message.xpath("/#{WinRM::NS_SOAP_ENV}:Envelope/#{WinRM::NS_SOAP_ENV}:Body/#{WinRM::NS_ENUM}:Pull/#{WinRM::NS_ENUM}:EnumerationContext").text.should == '1234' }
      it { message.xpath("/#{WinRM::NS_SOAP_ENV}:Envelope/#{WinRM::NS_SOAP_ENV}:Body/#{WinRM::NS_ENUM}:Pull/#{WinRM::NS_ENUM}:MaxElements").text.should == request.max_elements.to_s }
    end
  end
end