require_relative 'file_transfer/remote_file'
require_relative 'file_transfer/temp_zip_file'

module WinRM
  # Perform file transfer operations between a local machine and winrm endpoint
  class FileManager

    # Creates a new FileManager instance
    # @param [WinRMWebService] WinRM web service client
    def initialize(service)
      @service = service
      @logger = Logging.logger[self]
    end

    # Create the specifed directory recursively
    # @param [String] The remote dir to create
    # @return [Boolean] True if successful, otherwise false
    def create_dir(path)
      @logger.debug("create_dir: #{path}")
      script = <<-EOH
        $path = [System.IO.Path]::GetFullPath('#{path}')
        if (!(test-path $path)) {
          ni -itemtype directory -force -path $path | out-null
          exit $LASTEXITCODE
        }
        exit 0
      EOH
      @service.powershell(script)[:exitcode] == 0
    end

    # Deletes the file or directory at the specified path
    # @param [String] The path to remove
    # @return [Boolean] True if successful, otherwise False
    def delete(path)
      @logger.debug("deleting: #{path}")
      script = <<-EOH
        $path = [System.IO.Path]::GetFullPath('#{path}')
        if (test-path $path) {
          ri $path -force -recurse
          exit $LASTEXITCODE
        }
        exit 0
      EOH
      @service.powershell(script)[:exitcode] == 0
    end

    # Downloads the specified remote file to the specified local path
    # @param [String] The full path on the remote machine
    # @param [String] The full path to write the file to locally
    def download(remote_path, local_path)
      @logger.debug("downloading: #{remote_path} -> #{local_path}")
      script = <<-EOH
        $path = [System.IO.Path]::GetFullPath('#{remote_path}')
        if (test-path $path) {
          [System.convert]::ToBase64String([System.IO.File]::ReadAllBytes($path))
          exit 0
        }
        exit 1
      EOH
      output = @service.powershell(script)
      return false if output[:exitcode] != 0

      contents = output[:data].map!{|line| line[:stdout]}.join.gsub("\\n\\r", '')
      out = Base64.decode64(contents)
      IO.binwrite(local_path, out)

      true
    end

    # Checks to see if the given path exists on the target file system.
    # @param [String] The full path to the directory or file
    # @return [Boolean] True if the file/dir exists, otherwise false.
    def exists?(path)
      @logger.debug("exists?: #{path}")
      script = <<-EOH
        $path = [System.IO.Path]::GetFullPath('#{path}')
        if (test-path $path) { exit 0 } else { exit 1 }
      EOH
      @service.powershell(script)[:exitcode] == 0
    end

    # Gets the current user's TEMP directory on the remote system
    # @return [String] Full path to the temp directory
    def temp_dir
      @guest_temp ||= (@service.cmd('echo %TEMP%'))[:data][0][:stdout].chomp.gsub('\\', '/')
    end

    # Upload one or more local files and directories to a remote directory
    # @example copy a single directory to a winrm endpoint
    #
    #   file_manager.upload('c:/dev/my_dir', '$env:AppData')
    #
    # @example copy several paths to the winrm endpoint
    #
    #   file_manager.upload(['c:/dev/file1.txt','c:/dev/dir1'], '$env:AppData')
    #
    # @param [Array<String>] One or more paths that will be copied to the remote path.
    #   These can be files or directories to be deeply copied
    # @param [String] The target directory or file
    #   This path may contain powershell style environment variables
    # @yieldparam [Fixnum] Number of bytes copied in current payload sent to the winrm endpoint
    # @yieldparam [Fixnum] The total number of bytes to be copied
    # @yieldparam [String] Path of file being copied
    # @yieldparam [String] Target path on the winrm endpoint
    # @return [Fixnum] The total number of bytes copied
    def upload(local_paths, remote_path, &block)
      @logger.debug("uploading: #{local_paths} -> #{remote_path}")
      local_paths = [local_paths] if local_paths.is_a? String

      if FileManager.src_is_single_file?(local_paths)
        upload_file(local_paths[0], remote_path, &block)
      else
        upload_multiple_files(local_paths, remote_path, &block)
      end
    end

    private

    def upload_file(src_file, remote_path, &block)
      # If the src has a file extension and the destination does not
      # we can assume the caller specified the dest as a directory
      if File.extname(src_file) != '' && File.extname(remote_path) == ''
        remote_path = File.join(remote_path, File.basename(src_file))
      end

      # Upload the single file and decode on the target
      remote_file = RemoteFile.single_remote_file(@service)
      remote_file.upload(src_file, remote_path, &block) 
    end

    def upload_multiple_files(local_paths, remote_path, &block)
      temp_zip = FileManager.create_temp_zip_file(local_paths)

      # Upload and extract the zip file on the target
      remote_file = RemoteFile.multi_remote_file(@service)
      remote_file.upload(temp_zip.path, remote_path, &block)
    ensure
      temp_zip.delete() if temp_zip
    end

    def self.create_temp_zip_file(local_paths)
      temp_zip = WinRM::TempZipFile.new()
      local_paths.each { |p| temp_zip.add(p) }
      temp_zip
    end

    def self.src_is_single_file?(local_paths)
      local_paths.count == 1 && File.file?(local_paths[0])
    end
  end
end