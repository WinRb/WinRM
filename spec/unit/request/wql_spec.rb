require 'spec_helper'

describe WinRM::Request::Wql do

 let(:client) do
    WinRM::Client.new('localhost', user: 'vagrant', pass: 'vagrant')
  end

  let(:request) do
    WinRM::Request::Wql.new(client, query: 'select * from Win32_Process')
  end

  context 'null query' do
    let(:request) do
      WinRM::Request::Wql.new(client)
    end

    it { expect { request.to_s }.to raise_error(ArgumentError) }
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

  describe '.execute' do 
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

    it { request.execute.should == [{:caption=>"System Idle Process", :command_line=>nil, :creation_class_name=>"Win32_Process", :creation_date=>nil, :cs_creation_class_name=>"Win32_ComputerSystem", :cs_name=>"VAGRANT-2008R2", :description=>"System Idle Process", :executable_path=>nil, :execution_state=>nil, :handle=>"0", :handle_count=>"0", :install_date=>nil, :kernel_mode_time=>"33618906250", :maximum_working_set_size=>nil, :minimum_working_set_size=>nil, :name=>"System Idle Process", :os_creation_class_name=>"Win32_OperatingSystem", :os_name=>"Microsoft Windows Server 2008 R2 Standard |C:\\Windows|\\Device\\Harddisk0\\Partition1", :other_operation_count=>"0", :other_transfer_count=>"0", :page_faults=>"1", :page_file_usage=>"0", :parent_process_id=>"0", :peak_page_file_usage=>"0", :peak_virtual_size=>"0", :peak_working_set_size=>"24", :priority=>"0", :private_page_count=>"0", :process_id=>"0", :quota_non_paged_pool_usage=>"0", :quota_paged_pool_usage=>"0", :quota_peak_non_paged_pool_usage=>"0", :quota_peak_paged_pool_usage=>"0", :read_operation_count=>"0", :read_transfer_count=>"0", :session_id=>"0", :status=>nil, :termination_date=>nil, :thread_count=>"1", :user_mode_time=>"0", :virtual_size=>"0", :windows_version=>"6.1.7601", :working_set_size=>"24576", :write_operation_count=>"0", :write_transfer_count=>"0", :"@xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance", :"@xmlns:p"=>"http://schemas.microsoft.com/wbem/wsman/1/wmi/root/cimv2/Win32_Process", :"@xmlns:cim"=>"http://schemas.dmtf.org/wbem/wscim/1/common", :"@xsi:type"=>"p:Win32_Process_Type"}, {:caption=>"System", :command_line=>nil, :creation_class_name=>"Win32_Process", :creation_date=>{:datetime=>"2013-04-29T11:43:11.203125-07:00"}, :cs_creation_class_name=>"Win32_ComputerSystem", :cs_name=>"VAGRANT-2008R2", :description=>"System", :executable_path=>nil, :execution_state=>nil, :handle=>"4", :handle_count=>"520", :install_date=>nil, :kernel_mode_time=>"1906718750", :maximum_working_set_size=>nil, :minimum_working_set_size=>nil, :name=>"System", :os_creation_class_name=>"Win32_OperatingSystem", :os_name=>"Microsoft Windows Server 2008 R2 Standard |C:\\Windows|\\Device\\Harddisk0\\Partition1", :other_operation_count=>"8136", :other_transfer_count=>"363517", :page_faults=>"20406", :page_file_usage=>"112", :parent_process_id=>"0", :peak_page_file_usage=>"268", :peak_virtual_size=>"7217152", :peak_working_set_size=>"3852", :priority=>"8", :private_page_count=>"114688", :process_id=>"4", :quota_non_paged_pool_usage=>"0", :quota_paged_pool_usage=>"0", :quota_peak_non_paged_pool_usage=>"0", :quota_peak_paged_pool_usage=>"0", :read_operation_count=>"104", :read_transfer_count=>"33032692", :session_id=>"0", :status=>nil, :termination_date=>nil, :thread_count=>"76", :user_mode_time=>"0", :virtual_size=>"3461120", :windows_version=>"6.1.7601", :working_set_size=>"49152", :write_operation_count=>"11083", :write_transfer_count=>"61354599", :"@xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance", :"@xmlns:p"=>"http://schemas.microsoft.com/wbem/wsman/1/wmi/root/cimv2/Win32_Process", :"@xmlns:cim"=>"http://schemas.dmtf.org/wbem/wscim/1/common", :"@xsi:type"=>"p:Win32_Process_Type"}, {:caption=>"conhost.exe", :command_line=>"\\??\\C:\\Windows\\system32\\conhost.exe", :creation_class_name=>"Win32_Process", :creation_date=>{:datetime=>"2013-04-29T13:09:06.102138-07:00"}, :cs_creation_class_name=>"Win32_ComputerSystem", :cs_name=>"VAGRANT-2008R2", :description=>"conhost.exe", :executable_path=>"C:\\Windows\\system32\\conhost.exe", :execution_state=>nil, :handle=>"1100", :handle_count=>"34", :install_date=>nil, :kernel_mode_time=>"156250", :maximum_working_set_size=>"1380", :minimum_working_set_size=>"200", :name=>"conhost.exe", :os_creation_class_name=>"Win32_OperatingSystem", :os_name=>"Microsoft Windows Server 2008 R2 Standard |C:\\Windows|\\Device\\Harddisk0\\Partition1", :other_operation_count=>"16", :other_transfer_count=>"124", :page_faults=>"556", :page_file_usage=>"860", :parent_process_id=>"312", :peak_page_file_usage=>"860", :peak_virtual_size=>"23941120", :peak_working_set_size=>"2192", :priority=>"8", :private_page_count=>"880640", :process_id=>"1100", :quota_non_paged_pool_usage=>"5", :quota_paged_pool_usage=>"47", :quota_peak_non_paged_pool_usage=>"5", :quota_peak_paged_pool_usage=>"49", :read_operation_count=>"0", :read_transfer_count=>"0", :session_id=>"0", :status=>nil, :termination_date=>nil, :thread_count=>"2", :user_mode_time=>"0", :virtual_size=>"23060480", :windows_version=>"6.1.7601", :working_set_size=>"241664", :write_operation_count=>"0", :write_transfer_count=>"0", :"@xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance", :"@xmlns:p"=>"http://schemas.microsoft.com/wbem/wsman/1/wmi/root/cimv2/Win32_Process", :"@xmlns:cim"=>"http://schemas.dmtf.org/wbem/wscim/1/common", :"@xsi:type"=>"p:Win32_Process_Type"}]  }
  end
end