require 'spec_helper'

describe WinRM::Response do
  let(:response) { described_class.new(exit_code, output) }
  let(:exit_code) { 0 }
  let(:output) { [{:stderr=>"'foo' is not recognized as an internal or external command,\r\noperable program or batch file.\r\n"}] }

  it "has an exit code" do
    expect(response.exit_code).to eql(0)
  end

  describe "#success?" do
    context "when the exit code is 0" do
      it "returns true" do
        expect(response.success?).to eql(true)
      end
    end

    context "when the exit code is non-zero" do
      let(:exit_code) { 1 }
      it "returns false" do
        expect(response.success?).to eql(false)
      end
    end
  end

  describe "#error?" do
    context "when the exit code is 0" do
      it "returns false" do
        expect(response.error?).to eql(false)
      end
    end

    context "when the exit code is non-zero" do
      let(:exit_code) { 1 }
      it "returns true" do
        expect(response.error?).to eql(true)
      end
    end
  end

  describe "#output" do
    it "returns a String" do
      expect(response.output).to be_a(String)
    end
  end
end
