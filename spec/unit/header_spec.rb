require 'spec_helper'

describe WinRM::Headers do
  before(:all) do
    class ::WinRM::HeaderClass
      include WinRM::Headers
    end
  end

  let(:instance) do
    WinRM::HeaderClass.new
  end

  describe '.merge_headers' do
    include WinRM::Headers
    subject(:headers) { instance.merge_headers({header1: :value1}, get_action(:delete), {:attributes! => {:test => :test} } ) }
    it { should == { :header1=>:value1, "a:Action"=>"http://schemas.xmlsoap.org/ws/2004/09/transfer/Delete", :attributes! => {"a:Action" => {"s:mustUnderstand"=>true}, :test=>:test} } }
  end

  describe '.selector_shell_id' do
    subject(:selector) {instance.selector_shell_id("1")}
    it { should == {"w:SelectorSet"=>{"w:Selector"=>"1", :attributes! => {"w:Selector"=>{"Name"=>"ShellId"}}}} }
  end
end
