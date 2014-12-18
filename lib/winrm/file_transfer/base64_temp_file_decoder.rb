require_relative 'command_executor'

module WinRM
  class Base64TempFileDecoder

    def initialize(command_executor)
      @command_executor = command_executor
    end

    def decode(temp_file_path, dest_file_path)
      script = decode_script(temp_file_path, dest_file_path)
      @command_executor.run_powershell(script)
    end

    private

    def decode_script(temp_file_path, dest_file_path)
      <<-EOH
        $tempFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath('#{temp_file_path}')
        $destFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath('#{dest_file_path}')

        # ensure the file's containing directory exists
        $destDir = ([System.IO.Path]::GetDirectoryName($destFile))
        if (!(Test-Path $destDir)) {
          New-Item -ItemType directory -Force -Path $destDir | Out-Null
        }

        # get the encoded temp file contents, decode, and write to final dest file
        $base64Content = Get-Content $tempFile
        if ($base64Content -eq $null) {
          New-Item -ItemType file -Force $destFile
        } else {
          $bytes = [System.Convert]::FromBase64String($base64Content)
          [System.IO.File]::WriteAllBytes($destFile, $bytes) | Out-Null
        }
      EOH
    end
  end
end