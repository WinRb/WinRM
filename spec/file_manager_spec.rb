describe WinRM::FileManager, :integration => true do
  let(:dest_dir) { File.join(subject.temp_dir, "winrm_#{rand(2**16)}") }
  let(:src_dir) { File.expand_path(File.dirname(__FILE__)) }
  let(:service) { winrm_connection }

  subject { WinRM::FileManager.new(service) }

  context 'exists?' do
    it 'should exist' do
      expect(subject.exists?('c:/windows')).to be true
      expect(subject.exists?('c:/foobar')).to be false
    end
  end

  context 'create and delete dir' do
    it 'should create the directory recursively' do
      subdir = File.join(dest_dir, 'subdir1', 'subdir2')
      expect(subject.create_dir(subdir)).to be true
      expect(subject.exists?(subdir)).to be true
      expect(subject.create_dir(subdir)).to be true
      expect(subject.delete(subdir)).to be true
      expect(subject.exists?(subdir)).to be false
    end
  end

  context 'temp_dir' do
    it 'should return the remote users temp dir' do
      expect(subject.temp_dir).to match(/C:\/Users\/\w+\/AppData\/Local\/Temp/)
    end
  end

  context 'upload file' do
    let(:src_file) { __FILE__ }
    let(:dest_file) { File.join(dest_dir, File.basename(src_file)) }

    before(:each) do
      expect(subject.delete(dest_dir)).to be true
    end

    it 'should upload the file to the specified file' do
      subject.upload(src_file, dest_file)
      expect(subject).to have_created(dest_file).with_content(src_file)
    end

    it 'should upload the file to the specified directory' do
      subject.upload(src_file, dest_dir)
      expect(subject).to have_created(dest_file).with_content(src_file)
    end

    it 'should upload the file to the specified directory with env var' do
      subject.upload(src_file, '$env:Temp')
      expected_dest_file = File.join(subject.temp_dir, File.basename(src_file))
      expect(subject).to have_created(expected_dest_file).with_content(src_file)
    end

    it 'should upload the file to the specified nested directory' do
      dest_sub_dir = File.join(dest_dir, 'subdir')
      dest_sub_dir_file = File.join(dest_sub_dir, File.basename(src_file))
      subject.upload(src_file, dest_sub_dir)
      expect(subject).to have_created(dest_sub_dir_file)
    end

    it 'yields progress data' do
      total = subject.upload(src_file, dest_file) do |bytes_copied, total_bytes, local_path, remote_path|
        expect(total_bytes).to be > 0
        expect(bytes_copied).to eq(total_bytes)
        expect(local_path).to eq(src_file)
        expect(remote_path).to eq(dest_file)
      end
      expect(total).to be > 0
    end

    it 'should not upload the file when content matches' do
      subject.upload(src_file, dest_dir)
      bytes_uploaded = subject.upload(src_file, dest_dir)
      expect(bytes_uploaded).to eq 0
    end

    it 'should upload file when content differs' do
      another_src_file = File.join(src_dir, 'matchers.rb')
      subject.upload(another_src_file, dest_file)
      bytes_uploaded = subject.upload(src_file, dest_file)
      expect(bytes_uploaded).to be > 0
    end

    it 'raises WinRMUploadError when a bad source path is specified' do
      expect { subject.upload('c:/some/non-existant/path/foo', dest_file) }.to raise_error
    end
  end

  context 'upload empty file' do
    let(:src_file) { __FILE__ }
    let(:empty_src_file) { Tempfile.new('empty').path }
    let(:dest_file) { File.join(dest_dir, 'emptyfile.txt') }

    it 'creates a new empty file' do
      expect(subject.upload(empty_src_file, dest_file)).to be 0
      expect(subject).to have_created(dest_file).with_content('')
    end

    it 'overwrites an existing file' do
      expect(subject.upload(src_file, dest_file)).to be > 0
      expect(subject.upload(empty_src_file, dest_file)).to be 0
      expect(subject).to have_created(dest_file).with_content('')
    end
  end

  context 'upload directory' do
    before(:each) do
      expect(subject.delete(dest_dir)).to be true
    end

    it 'copies the entire directory' do
      bytes_uploaded = subject.upload(src_dir, dest_dir)
      expect(bytes_uploaded).to be > 0
      Dir.glob(src_dir + '/*.rb').each do |host_file|
        host_file_rel = host_file[src_dir.length..-1]
        remote_file = File.join(dest_dir, host_file_rel)
        expect(subject).to have_created(remote_file).with_content(host_file)
      end
    end

    it 'does not copy the directory when content is the same' do
      subject.upload(src_dir, dest_dir)
      bytes_uploaded = subject.upload(src_dir, dest_dir)
      expect(bytes_uploaded).to eq 0
    end

    it 'copies the directory when content differs' do
      subject.upload(src_dir, dest_dir)
      another_dir = File.dirname(src_dir)
      bytes_uploaded = subject.upload(another_dir, dest_dir)
      expect(bytes_uploaded).to be > 0
    end
  end
end
