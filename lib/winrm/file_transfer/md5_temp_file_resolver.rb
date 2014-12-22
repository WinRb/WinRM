require_relative 'command_executor'

module WinRM
  # Gets a unique path to a new temp file on the target machine
  class Md5TempFileResolver

    def initialize(command_executor)
      @command_executor = command_executor
    end

    # Gets the full path of a new empty temp file on the target machine, but
    # only if the source and target file contents differ. If the contents
    # match (i.e. upload isn't required) this will return ''
    #
    # @param [String] Full local path to the source file on this machine
    # @param [String] Full path to the file on the target machine
    # @return [String] Full path to a new tempfile, otherwise empty
    def temp_file_path(local_file, dest_file)
      script = temp_file_script(local_file, dest_file)
      @command_executor.run_powershell(script).to_s.chomp
    end

    private

    def temp_file_script(local_file, dest_file)
      local_md5 = Digest::MD5.file(local_file).hexdigest
      <<-EOH
        # get the resolved target path
        $destFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("#{dest_file}")

        # check if file is up to date
        if (Test-Path $destFile) {
          $cryptoProv = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider

          $file = [System.IO.File]::Open($destFile,
            [System.IO.Filemode]::Open, [System.IO.FileAccess]::Read)
          $guestMd5 = ([System.BitConverter]::ToString($cryptoProv.ComputeHash($file)))
          $guestMd5 = $guestMd5.Replace("-","").ToLower()
          $file.Close()

          # file content is up to date, send back an empty file path to signal this
          if ($guestMd5 -eq '#{local_md5}') {
            return ''
          }
        }

        # file doesn't exist or out of date, return a unique temp file path to upload to
        return [System.IO.Path]::GetTempFileName()
      EOH
    end
  end
end