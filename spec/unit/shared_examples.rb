shared_examples_for "a WinRM request" do
  context 'Headers' do
    describe 'ResourceURI' do 
      it { message.xpath("/#{WinRM::NS_SOAP_ENV}:Envelope/#{WinRM::NS_SOAP_ENV}:Header/#{WinRM::NS_WSMAN_DMTF}:ResourceURI").text.should == resource_uri }
    end
    
    describe 'Action' do 
      it { message.xpath("/#{WinRM::NS_SOAP_ENV}:Envelope/#{WinRM::NS_SOAP_ENV}:Header/#{WinRM::NS_ADDRESSING}:Action").text.should == action }
    end

    describe 'To' do
      it { message.xpath("/#{WinRM::NS_SOAP_ENV}:Envelope/#{WinRM::NS_SOAP_ENV}:Header/#{WinRM::NS_ADDRESSING}:To").text.should == "http://localhost:5985/wsman" }
    end

    describe 'Address' do
      it { message.xpath("/#{WinRM::NS_SOAP_ENV}:Envelope/#{WinRM::NS_SOAP_ENV}:Header/#{WinRM::NS_ADDRESSING}:ReplyTo/#{WinRM::NS_ADDRESSING}:Address").text.should == "http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous" }
    end

    describe 'MaxEnvelopeSize' do
      it { message.xpath("/#{WinRM::NS_SOAP_ENV}:Envelope/#{WinRM::NS_SOAP_ENV}:Header/#{WinRM::NS_WSMAN_DMTF}:MaxEnvelopeSize").text.should == "512000" }
    end

    describe 'MessageID' do
      it { message.xpath("/#{WinRM::NS_SOAP_ENV}:Envelope/#{WinRM::NS_SOAP_ENV}:Header/#{WinRM::NS_ADDRESSING}:MessageID").text.split(':')[0].should == 'uuid' }
      it { t, u = message.xpath("/#{WinRM::NS_SOAP_ENV}:Envelope/#{WinRM::NS_SOAP_ENV}:Header/#{WinRM::NS_ADDRESSING}:MessageID").text.split(':')[1].should be_a_kind_of(String)}
    end

    describe 'OperationTimeout' do
      it { message.xpath("/#{WinRM::NS_SOAP_ENV}:Envelope/#{WinRM::NS_SOAP_ENV}:Header/#{WinRM::NS_WSMAN_DMTF}:OperationTimeout").text.should == "PT60S" }
    end
  end

  describe '.to_s' do
    it { expect { message.header }.to_not raise_error(StandardError, "Not Implemented")}
    it { expect { message.body }.to_not raise_error(StandardError, "Not Implemented")}
    it { expect { message.to_s }.to_not raise_error(StandardError, "Not Implemented")}
  end
end

shared_examples_for "a WinRM selector set" do
  context 'SelectorSet' do
    it do 
      selectors.each do |k,v|
        message.xpath("/#{WinRM::NS_SOAP_ENV}:Envelope/#{WinRM::NS_SOAP_ENV}:Header/#{WinRM::NS_WSMAN_DMTF}:SelectorSet/#{WinRM::NS_WSMAN_DMTF}:Selector[@Name='#{k}']").text.should == v
      end
    end
    
  end
end

shared_examples_for "a WinRM option set" do
  context 'OptionSet' do
    it do 
      option_set.each do |k,v|
        message.xpath("/#{WinRM::NS_SOAP_ENV}:Envelope/#{WinRM::NS_SOAP_ENV}:Header/#{WinRM::NS_WSMAN_DMTF}:OptionSet/#{WinRM::NS_WSMAN_DMTF}:Option[@Name='#{k}']").text.should == v
      end
    end
    
  end
end