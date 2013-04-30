require 'spec_helper'

describe WinRM::WinRMHTTPTransportError do
  

  let(:instance) do
    i = WinRM::WinRMHTTPTransportError.new("Test Message", Object.new )
    i.stub(:http_body).and_return(File.read('spec/mock/wsman_fault.xml'))
    i
  end

  describe '.reason' do
    it { instance.reason.should == "The data source could not process the filter. The filter might be missing or it might be invalid. Change the filter and try the request again." }
  end

  describe '.provider' do
    it { instance.provider.should == 'WMI Provider' }
  end

  describe '.detail' do
    it { instance.detail.should == {:ws_man_fault => {:message=>{:provider_fault=>{:ws_man_fault=>{:message=>"The specified class does not exist in the given namespace. ", :"@xmlns:f"=>"http://schemas.microsoft.com/wbem/wsman/1/wsmanfault", :@code=>"2150858778", :@machine=>"vagrant-2008R2"}, :extended_error=>{:__extended_status=>{:description=>nil, :operation=>"ExecQuery", :parameter_info=>"Select * from Win32_Processa where name=\"sshd.exe\"", :provider_name=>"WinMgmt", :status_code=>nil, :"@xmlns:cim"=>"http://schemas.dmtf.org/wbem/wscim/1/common", :"@xmlns:p"=>"http://schemas.microsoft.com/wbem/wsman/1/wmi/root/cimv2/__ExtendedStatus", :"@xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance", :"@xsi:type"=>"p:__ExtendedStatus_Type"}}, :@path=>"%systemroot%\\system32\\WsmWmiPl.dll", :@provider=>"WMI Provider"}}, :"@xmlns:f"=>"http://schemas.microsoft.com/wbem/wsman/1/wsmanfault", :@code=>"2150858778", :@machine=>"localhost"}} }
  end

  describe '.code' do
    it { instance.code.should == 2150858778 }
  end

  describe '.fault_message' do
    it { instance.fault_message.should == 'The specified class does not exist in the given namespace.' }
  end
end
