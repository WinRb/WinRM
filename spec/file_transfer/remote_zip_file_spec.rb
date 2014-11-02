describe WinRM::RemoteZipFile, :integration => true do
  
  let(:this_dir) { File.dirname(__FILE__) }
  let(:service) { winrm_connection }
  let(:destination) {"#{ENV['temp']}/WinRM_tests"}
  before { FileUtils.rm_rf(Dir.glob("#{ENV['temp'].gsub("\\","/")}/WinRM_*")) }
  after { subject.close }
  subject {WinRM::RemoteZipFile.new(service, destination, :quiet => true)}

  context 'Upload a new directory' do
    it 'copies the directory' do
      subject.add_file(this_dir)
      expect(subject.upload).to be > 0
      expect(File.read(File.join(destination, "file_transfer", "remote_file_spec.rb"))).to eq(File.read(File.join(this_dir, 'remote_file_spec.rb')))
      expect(File.read(File.join(destination, "file_transfer", "remote_zip_file_spec.rb"))).to eq(File.read(File.join(this_dir, 'remote_zip_file_spec.rb')))
      expect(File.exist?(File.join(this_dir, "file_transfer.zip"))).to be_falsey
      expect(File.exist?(File.join(destination, "file_transfer.zip"))).to be_falsey
    end
  end

  context 'Upload an identical directory' do
    let (:next_transfer) {WinRM::RemoteZipFile.new(service, destination, :quiet => true)}

    it 'does not copy the directory' do
      subject.add_file(this_dir)
      expect(subject.upload).to be > 0
      next_transfer.add_file(this_dir)
      expect(next_transfer.upload).to be == 0
    end
  end

  context 'Upload multiple entries' do
    it 'copies each entry' do
      subject.add_file(this_dir)
      spec_helper = File.join(File.dirname(this_dir), 'spec_helper.rb')
      subject.add_file(spec_helper)
      expect(subject.upload).to be > 0
      expect(File.read(File.join(destination, "file_transfer", "remote_file_spec.rb"))).to eq(File.read(File.join(this_dir, 'remote_file_spec.rb')))
      expect(File.read(File.join(destination, "file_transfer", "remote_zip_file_spec.rb"))).to eq(File.read(File.join(this_dir, 'remote_zip_file_spec.rb')))
      expect(File.read(File.join(destination, "spec_helper.rb"))).to eq(File.read(spec_helper))
    end
  end

  context 'Upload a bad path' do
    it 'raises WinRMUploadFailed' do
      expect {
        subject.add_file('c:/some/bad/path')
        }.to raise_error(WinRM::WinRMUploadFailed)
    end
  end
end