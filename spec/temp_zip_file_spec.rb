require 'zip'
require_relative '../lib/winrm/file_transfer/temp_zip_file'

describe WinRM::TempZipFile, :integration => true do
  let(:src_dir) { File.expand_path(File.dirname(__FILE__)) }
  let(:src_file) { __FILE__ }

  subject { WinRM::TempZipFile.new() }
  after(:each) { subject.delete() }

  context 'temp file creation' do
    it 'should create a temp file on disk' do
      expect(File.exists?(subject.path)).to be true
      subject.delete()
      expect(File.exists?(subject.path)).to be false
    end
  end

  context 'add_file' do
    it 'should raise error when file doesn not exist' do
      expect { subject.add_file('/etc/foo/does/not/exist') }.to \
        raise_error('/etc/foo/does/not/exist isn\'t a file')
    end

    it 'should raise error when file is a directory' do
      dir = File.dirname(subject.path)
      expect { subject.add_file(dir) }.to \
        raise_error("#{dir} isn\'t a file")
    end

    it 'should add a file to the zip' do
      subject.add_file(src_file)
      expect(subject).to contain_zip_entries(File.basename(src_file))
    end
  end
  
  context 'add_directory' do
    it 'should raise error when directory does not exist' do
      expect { subject.add_directory('/etc/does/not/exist') }.to \
        raise_error('/etc/does/not/exist isn\'t a directory')
    end

    it 'should raise error when directory is a file' do
      expect { subject.add_directory(subject.path) }.to \
        raise_error("#{subject.path} isn\'t a directory")
    end

    it 'should add all files in directory to the zip recursively' do
      subject.add_directory(src_dir)
      expect(subject).to contain_zip_entries(['temp_zip_file_spec.rb', 'stubs/responses/open_shell_v1.xml'])
    end
  end

  context 'add' do
    it 'should add all files when given a directory' do
      subject.add(src_dir)
      expect(subject).to contain_zip_entries(['temp_zip_file_spec.rb', 'stubs/responses/open_shell_v1.xml'])
    end

    it 'should add a file when given only a file' do
      subject.add(src_file)
      expect(subject).to contain_zip_entries(File.basename(src_file))
    end

    it 'should raise error when given a non-path' do
      expect { subject.add('garbage') }.to \
        raise_error("garbage doesn't exist")
    end
  end
end
