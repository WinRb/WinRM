describe WinRM::RemoteZipFile, :integration => true do
  
  let(:this_dir) { File.dirname(__FILE__) }
  let(:service) { winrm_connection }
  let(:destination) {"C:/Users/Administrator/AppData/Local/Temp/winrm_tests"}
  before { 
    subject.service.run_command(subject.shell, "del /S/Q #{destination.gsub('/','\\')}") 
    subject.service.run_command(subject.shell, "del /S/Q C:\\Users\\Administrator\\AppData\\Local\\Temp\\WinRM_file_transfer") 
  }
  after { subject.close }
  subject {WinRM::RemoteZipFile.new(service, destination)}

  context 'Upload a new directory' do
    it 'copies the directory' do
      subject.add_file(this_dir)
      expect(subject.upload).to be > 0
      expect(subject).to have_same_content(File.join(this_dir, 'remote_file_spec.rb'), File.join(destination, "file_transfer", "remote_file_spec.rb"))
      expect(subject).to have_same_content(File.join(this_dir, 'remote_zip_file_spec.rb'), File.join(destination, "file_transfer", "remote_zip_file_spec.rb"))
      expect(subject).not_to have_remote_file(File.join(this_dir, "file_transfer.zip"))
      expect(subject).not_to have_remote_file(File.join(destination, "file_transfer.zip"))
    end
  end

  context 'Upload an identical directory' do
    let (:next_transfer) {WinRM::RemoteZipFile.new(service, destination)}

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
      expect(subject).to have_same_content(File.join(this_dir, 'remote_file_spec.rb'), File.join(destination, "file_transfer", "remote_file_spec.rb"))
      expect(subject).to have_same_content(File.join(this_dir, 'remote_zip_file_spec.rb'), File.join(destination, "file_transfer", "remote_zip_file_spec.rb"))
      expect(subject).to have_same_content(spec_helper, File.join(destination, "spec_helper.rb"))
    end
  end

  context 'Upload a bad path' do
    it 'raises WinRMUploadError' do
      expect {
        subject.add_file('c:/some/bad/path')
        }.to raise_error(WinRM::WinRMUploadError)
    end
  end
end