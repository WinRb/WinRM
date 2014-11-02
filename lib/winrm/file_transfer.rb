require 'winrm/file_transfer/remote_file'
require 'winrm/file_transfer/remote_zip_file'

module WinRM
  # Perform file transfer operations between a local machine and winrm endpoint
  class FileTransfer
    # Upload one or more local files and directories to a remote directory
    # @example copy a single directory to a winrm endpoint
    #
    #   WinRM::FileTransfer.upload(client, 'c:/dev/my_dir', '$env:AppData')
    #
    # @example copy several paths to the winrm endpoint
    #
    #   WinRM::FileTransfer.upload(client, ['c:/dev/file1.txt','c:/dev/dir1'], '$env:AppData')
    #
    # @param [WinRM::WinRMService] a winrm service client connected to the endpoint where the remote path resides
    # @param [Array<String>] One or more paths that will be copied to the remote path. These can be files or directories to be deeply copied
    # @param [String] The directory on the remote endpoint to copy the local items to. This path may contain powershell style environment variables
    # @option opts [String] options to be used for the copy. Currently only :quiet is supported to suppress the progress bar
    # @return [Fixnum] The total number of bytes copied
    def self.upload(service, local_path, remote_path, opts = {})
      file = nil
      local_path = [local_path] if local_path.is_a? String

      if local_path.count == 1 && !File.directory?(local_path[0])
        file = RemoteFile.new(service, local_path[0], remote_path, opts)
      else
        file = RemoteZipFile.new(service, remote_path, opts)
        local_path.each do |path|
          file.add_file(path)
        end
      end

      file.upload
    ensure
      file.close unless file.nil?
    end
  end
end