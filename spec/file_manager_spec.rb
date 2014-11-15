describe WinRM::FileManager, :integration => true do
  let(:service) { winrm_connection }
  let(:src_file) { __FILE__ }
  let(:dest_file) { File.join(subject.temp_dir, 'winrm_filemanager_test') }

  subject { WinRM::FileManager.new(service) }

  context 'temp_dir' do
    it 'should return the remote guests temp dir' do
      expect(subject.temp_dir).to eq('C:\Users\vagrant\AppData\Local\Temp')
    end
  end

  context 'upload' do
    it 'should upload the specified file' do
      subject.upload(src_file, dest_file)
      expect(subject.exists?(dest_file)).to be true
    end
  end
end
