describe WinRM::RemoteFile, :integration => true do

  let(:this_file) { __FILE__ }
  let(:empty_file) { Tempfile.new('empty').path }
  let(:service) { winrm_connection }
  let(:destination) {"C:/Users/Administrator/AppData/Local/Temp/winrm_tests"}
  after {
    if !subject.closed
      subject.service.run_command(subject.shell, "del /S/Q #{destination.gsub('/','\\')}")
      subject.close
    end
    FileUtils.rm_rf(destination)
  }

  context 'Upload a new file to directory path' do
    subject {WinRM::RemoteFile.new(service, this_file, destination)}

    it 'copies the file inside the directory' do
      expect(subject.upload).to be > 0
      expect(subject).to have_remote_file(File.join(destination, File.basename(this_file)))
    end
    it 'yields progress data' do
      total = subject.upload do |bytes_copied, total_bytes, local_path, remote_path|
        expect(total_bytes).to be > 0
        expect(bytes_copied).to eq(total_bytes)
        expect(local_path).to eq(subject.local_path)
        expect(remote_path).to eq(subject.remote_path)
      end
      expect(total).to be > 0
    end
    it 'copies the exact file content' do
      expect(subject.upload).to be > 0
      expect(subject).to have_same_content(this_file, subject.remote_path)
    end

  end

  context 'Upload an identical file to directory path' do
    subject {WinRM::RemoteFile.new(service, this_file, destination)}
    let (:next_transfer) {WinRM::RemoteFile.new(service, this_file, destination)}

    it 'does not copy the file' do
      expect(subject.upload).to be > 0
      expect(next_transfer.upload).to be == 0
    end
  end

  context 'Upload a file to file path' do
    subject {WinRM::RemoteFile.new(service, this_file, File.join(destination, File.basename(this_file)))}

    it 'copies the file to the exact path' do
      expect(subject.upload).to be > 0
      expect(subject).to have_remote_file(File.join(destination, File.basename(this_file)))
    end
  end


  context 'Upload an empty file' do
    subject {WinRM::RemoteFile.new(service, empty_file, File.join(destination, File.basename(empty_file)))}

    it 'creates an empty file at the exact path' do
      expect(subject.upload).to be 0
      expect(subject).to have_remote_file(File.join(destination, File.basename(empty_file))).with_attributes('Length' => 0)
    end
  end

  context 'Upload a new file to nested directory' do
    let (:nested) {File.join(destination, 'nested')}
    subject {WinRM::RemoteFile.new(service, this_file, nested)}

    it 'copies the file to the nested path' do
      expect(subject.upload).to be > 0
      expect(subject).to have_remote_file(File.join(nested, File.basename(this_file)))
    end
  end

  context 'Upload a file after RemoteFile is closed' do
    subject {WinRM::RemoteFile.new(service, this_file, destination)}

    it 'raises WinRMUploadError' do
      expect(subject.upload).to be > 0
      subject.close
      expect{subject.upload}.to raise_error(WinRM::WinRMUploadError)
    end
  end

  context 'Upload a bad path' do
    subject {WinRM::RemoteFile.new(service, 'c:/some/bad/path', destination)}

    it 'raises WinRMUploadError' do
      expect { subject.upload }.to raise_error(WinRM::WinRMUploadError)
    end
  end
end
