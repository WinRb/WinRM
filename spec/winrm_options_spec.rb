describe "Test WinRM options" do

	describe "Changed Options Integration", :integration => true do

		before(:all) do
			config = symbolize_keys(YAML.load(File.read(winrm_config_path)))
			config[:options].merge!(:receive_timeout => 10 ) unless config[:options]	[:receive_timeout].eql? 10
			config[:options].merge!( :basic_auth_only => true ) unless config[:auth_type].eql? :kerberos
			@winrm = WinRM::WinRMWebService.new(config[:endpoint], config[:auth_type].to_sym, config[:options])
		end
			
    it 'should have receive timeout of 10' do      
			transportclass 	= @winrm.instance_variable_get(:@xfer)
			httpcli					= transportclass.instance_variable_get(:@httpcli)
			expect(httpcli.receive_timeout).to eql(10)
			
		end
	end
	
	describe "Default Options Integration", :integration => true do
		before(:all) do
			@winrm = winrm_connection
		end
	
		it 'should have a default timeout of 3600' do
			transportclass 	= @winrm.instance_variable_get(:@xfer)
			httpcli					= transportclass.instance_variable_get(:@httpcli)
			expect(httpcli.receive_timeout).to eql(3600)
			
		end
	end
end
