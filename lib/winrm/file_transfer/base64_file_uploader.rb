require_relative 'command_executor'

module WinRM
  class Base64FileUploader

    def initialize(command_executor)
      @command_executor = command_executor
    end

    # Uploads the given file to the specified temp file as base64 encoded.
    #
    # @param [String] Local path to the source file on this machine
    # @param [String] Path to the temporary file on the target machine
    # @param [String] Path to the final location on the target machine
    # @return [Integer] Count of bytes uploaded
    def upload_to_temp_file(local_file_path, temp_file_path, remote_file_path, &block)
      base64_host_file = Base64.encode64(IO.binread(local_file_path)).gsub("\n", "")
      base64_array = base64_host_file.chars.to_a
      bytes_copied = 0
      
      base64_array.each_slice(8000 - temp_file_path.size) do |chunk|
        @command_executor.run_cmd("echo #{chunk.join} >> \"#{temp_file_path}\"")
        bytes_copied += chunk.count
        yield bytes_copied, base64_array.count, local_file_path, remote_file_path if block_given?
      end

      base64_array.length
    end
  end
end