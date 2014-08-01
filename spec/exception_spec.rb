module WinRM
  describe "Exceptions", :unit => true do
    before(:all) do
      @error = WinRMHTTPTransportError.new("Foo happened", 500)
    end

    it 'adds the response code to the message' do
      expect(@error.message).to eql('Foo happened (500).')
    end

    it 'exposes the response code as an attribute' do
      expect(@error.response_code).to be 500
    end
  end
end
