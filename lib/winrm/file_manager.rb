require 'winrm/file_transfer/remote_file'
require 'winrm/file_transfer/remote_zip_file'

module WinRM
  # Perform file transfer operations between a local machine and winrm endpoint
  class FileManager

    # Creates a new FileManager instance
    # @param [WinRMWebService] WinRM web service client
    def initialize(service)
      @service = service
    end

    # Downloads the specified remote file to the specified local path
    # @param [String] The full path on the remote machine
    # @param [String] The full path to write the file to locally
    def download(remote_path, local_path)
      script = <<-EOH
        $path = [System.IO.Path]::GetFullPath('#{remote_path}')
        [System.convert]::ToBase64String([System.IO.File]::ReadAllBytes($path))
      EOH
      output = @service.powershell(script)
      contents = output[:data].map!{|line| line[:stdout]}.join.gsub("\\n\\r", '')
      out = Base64.decode64(contents)
      IO.binwrite(local_path, out)
    end

    # Checks to see if the given path exists on the target file system.
    # @param [String] The full path to the directory or file
    # @return [Boolean] True if the file/dir exists, otherwise false.
    def exists?(path)
      script = <<-EOH
        $path = [System.IO.Path]::GetFullPath('#{path}')
        if (Test-Path $path) { exit 0 } else { exit 1 }")
      EOH
      @service.powershell(script)[:exitcode] == 0
    end

    # Gets the current user's TEMP directory on the remote system
    # @return [String] Full path to the temp directory
    def temp_dir
      @guest_temp ||= (@service.cmd('echo %TEMP%'))[:data][0][:stdout].chomp
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
    # @param [String] The directory on the remote endpoint to copy the local items to.
    #   This path may contain powershell style environment variables
    # @yieldparam [Fixnum] Number of bytes copied in current payload sent to the winrm endpoint
    # @yieldparam [Fixnum] The total number of bytes to be copied
    # @yieldparam [String] Path of file being copied
    # @yieldparam [String] Target path on the winrm endpoint
    # @return [Fixnum] The total number of bytes copied
    def upload(local_path, remote_path, &block)
      local_path = [local_path] if local_path.is_a? String
      file = create_remote_file(local_path, remote_path)
      file.upload(&block)
    end

    private

    def create_remote_file(local_paths, remote_path)
      if local_paths.count == 1 && !File.directory?(local_paths[0])
        return RemoteFile.new(@service, local_paths[0], remote_path)
      end
      zip_file = RemoteZipFile.new(@service, remote_path)
      local_paths.each { |path| zip_file.add_file(path) }
      zip_file
    end
  end
end