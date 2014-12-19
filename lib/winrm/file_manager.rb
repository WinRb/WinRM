require_relative 'file_transfer/remote_file'
require_relative 'file_transfer/temp_zip_file'
require_relative 'file_transfer/base64_file_decoder'
require_relative 'file_transfer/base64_zip_file_decoder'
require_relative 'file_transfer/base64_file_uploader'
require_relative 'file_transfer/md5_temp_file_resolver'
require_relative 'file_transfer/command_executor'

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
      local_paths = [local_paths] if local_paths.is_a? String
      remote_path = remote_path.gsub('\\', '/')
      bytes = 0

      cmd_executor = WinRM::CommandExecutor.new(@service)
      cmd_executor.open()

      # Specifying a single src file to upload is a special case
      if local_paths.count == 1 && !File.directory?(local_paths[0])
        src_file = local_paths[0]

        # If the src has a file extension and the destination does not
        # we can assume the caller specified the dest as a directory
        if File.extname(src_file) != '' && File.extname(remote_path) == ''
          remote_path = File.join(remote_path, File.basename(src_file))
        end

        remote_file = create_remote_file(cmd_executor)
        bytes = remote_file.upload(src_file, remote_path, &block)       
      else
        #upload_path = File.join(temp_dir, "winrm-upload-#{rand()}.zip").gsub('\\', '/')

        # Create and upload the zip file
        temp_zip = create_temp_zip_file(local_paths)
        #remote_file = RemoteFile.new(cmd_executor, temp_zip.path, upload_path)
        #bytes = remote_file.upload(&block)

        # Extract the zip file
        remote_file = create_remote_file(cmd_executor, true)
        bytes = remote_file.upload(temp_zip.path, remote_path, &block) 

        #output = @service.powershell(extract_zip_command(upload_path, remote_path))
        #raise WinRMUploadError.new(output.output) if output[:exitcode] != 0
      end

      bytes
    ensure
      cmd_executor.close() if cmd_executor
      temp_zip.delete() if temp_zip
    end

    private

    def create_remote_file(cmd_executor, zip = false)
      temp_file_resolver = WinRM::Md5TempFileResolver.new(cmd_executor)
      file_uploader = WinRM::Base64FileUploader.new(cmd_executor)
      file_decoder = if zip then
        WinRM::Base64ZipFileDecoder.new(cmd_executor)
      else
        WinRM::Base64FileDecoder.new(cmd_executor)
      end
      WinRM::RemoteFile.new(temp_file_resolver, file_uploader, file_decoder)
    end

    def create_temp_zip_file(local_paths)
      temp_zip = WinRM::TempZipFile.new()
      local_paths.each do |local_path|
        if File.directory?(local_path)
          temp_zip.add_directory(local_path)
        elsif File.file?(local_path)
          temp_zip.add_file(local_path)
        else
          raise "#{local_path} doesn't exist"
        end
      end
      temp_zip
    end
  end
end