describe WinRM::FileManager, :unit => true do
  let(:this_file) { __FILE__ }
  let(:remote_file) { double('RemoteFile') }
  let(:remote_zip_file) { double('RemoteZipFile') }
  let(:service) { double('service') }

  subject { WinRM::FileManager.new(service) }
  
  before(:each) do
    allow(WinRM::RemoteFile).to receive(:new).and_return(remote_file)
    allow(WinRM::RemoteZipFile).to receive(:new).and_return(remote_zip_file)
  end

  context 'copying a single file' do
    it 'uploads a remote_file' do
      expect(remote_file).to receive(:upload)
      expect(remote_file).to receive(:close)
      subject.upload(this_file, "c:/directory")
    end
  end

  context 'copying a single directory' do
    it 'uploads a remote_zip_file' do
      expect(remote_zip_file).to receive(:add_file).with(File.dirname(this_file))
      expect(remote_zip_file).to receive(:upload)
      expect(remote_zip_file).to receive(:close)
      subject.upload(File.dirname(this_file), "c:/directory")
    end
  end

  context 'copying both a file and a directory' do
    it 'adds both to a remote_zip_file' do
      expect(remote_zip_file).to receive(:upload)
      expect(remote_zip_file).to receive(:add_file).with(this_file)
      expect(remote_zip_file).to receive(:add_file).with(File.dirname(this_file))
      expect(remote_zip_file).to receive(:close)
      subject.upload([File.dirname(this_file), this_file], "c:/directory")
    end
  end
end
