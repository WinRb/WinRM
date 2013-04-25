require 'spec_helper'

describe WinRM::Request::InvokeWmi do

 let(:client) do
    WinRM::Client.new('localhost', user: 'vagrant', pass: 'vagrant')
  end


  let(:request) do
    WinRM::Request::InvokeWmi.new(client, shell_id: 123, wmi_class: 'CIM_DataFile', method: 'Delete', selectors: {Name: "C:\\\\Temp\\\\file"}, arguments: {fake: :argument} )
  end

  subject(:message) { Nokogiri::XML(request.to_s) }

  it_should_behave_like "a WinRM request" do
    let(:resource_uri) { 'http://schemas.microsoft.com/wbem/wsman/1/wmi/root/cimv2/CIM_DataFile' }
    let(:action) { "http://schemas.microsoft.com/wbem/wsman/1/wmi/root/cimv2/CIM_DataFile/Delete" }
  end

  it_should_behave_like "a WinRM selector set" do
    let(:selectors) { { Name:  "C:\\\\Temp\\\\file" } }
  end

  describe '.to_s' do
    context 'body' do
      it { message.xpath("/#{WinRM::NS_SOAP_ENV}:Envelope/#{WinRM::NS_SOAP_ENV}:Body/#{WinRM::NS_WSMAN_MSFT}:Delete_INPUT/#{WinRM::NS_WSMAN_MSFT}:fake").text.should == "argument" }
    end
  end

end

