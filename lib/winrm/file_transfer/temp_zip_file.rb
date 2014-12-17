require 'zip'

module WinRM
  class TempZipFile

    attr_reader :path

    def initialize()
      @logger = Logging.logger[self]
      @zip_file = Tempfile.new(['winrm_upload', '.zip'])
      @zip_file.close()
      @path = @zip_file.path
    end

    # Adds all files in the specified directory recursively into the zip file
    # @param [String] Directory to add into zip
    def add_directory(dir)
      raise "#{dir} isn't a directory" unless File.directory?(dir)
      glob = File.join(dir, "**/*")
      Dir.glob(glob).each do |file|
        add_file_entry(file, dir)
      end
    end
    
    def add_file(file)
      raise "#{file} doesn't exist" unless File.exists?(file)
      raise "#{file} isn't a file" unless File.file?(file)
      add_file_entry(file, File.dirname(file))
    end

    def delete()
      @zip_file.delete()
    end

    private

    def add_file_entry(file, base_dir)
      base_dir = "#{base_dir}/" unless base_dir.end_with?('/')
      file_entry_path = file[base_dir.length..-1]
      write_zip_entry(file, file_entry_path)
    end

    def write_zip_entry(file, file_entry_path)
      @logger.debug("adding zip entry: #{file_entry_path}")
      Zip::File.open(@path, 'w') do |zipfile|
        entry = Zip::Entry.new(@path, file_entry_path, \
          nil, nil, nil, nil, nil, nil, ::Zip::DOSTime.new(2000))
        zipfile.add(entry, file)
      end
    end
  end
end
