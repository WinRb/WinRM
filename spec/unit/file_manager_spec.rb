require 'spec_helper'

describe WinRM::FileManager do
  let(:client) do
    WinRM::Client.new('localhost', user: 'vagrant', pass: 'vagrant')
  end

  subject(:instance) do
    WinRM::FileManager.new(client)
  end

  describe '.directory?' do
    it {instance.directory?("C:\\Temp").should be(true)}
    it {instance.file?("C:\\Temp").should be(false)}
  end

 
end