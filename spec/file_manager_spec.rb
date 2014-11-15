describe WinRM::FileManager, :integration => true do
  let(:service) { winrm_connection }
  let(:src_file) { __FILE__ }
  #let(:dest_file) { File.join(dest_temp_dir, 'winrm_filemanager_test') }

  subject { WinRM::FileManager.new(service) }

  context 'temp_dir' do
    it 'should return the remote guests temp dir' do
      expect(subject.temp_dir).to eq('C:\Users\vagrant\AppData\Local\Temp')
    end
  end
end
