require_relative '../helpers/powershell_script'

module WinRM
  # Executes commands used by the WinRM file management module
  class CommandExecutor
    def initialize(service)
      @service = service
    end

    def open()
      @shell = @service.open_shell()
      @shell_open = true
    end

    def close()
      @service.close_shell(@shell) if @shell
      @shell_open = false
    end

    def run_powershell(script_text)
      assert_shell_is_open()
      script = WinRM::PowershellScript.new(script_text)
      run_cmd("powershell", ['-encodedCommand', script.encoded()])
    end

    def run_cmd(command, arguments = [])
      assert_shell_is_open()
      result = nil
      @service.run_command(@shell, command, arguments) do |command_id|
        result = @service.get_command_output(@shell, command_id)
      end
      assert_command_succeed(result)
      result.stdout
    end

    private

    def assert_shell_is_open()
      raise 'You must call open before calling any run methods' unless @shell_open
    end

    def assert_command_succeed(result)
      if result[:exitcode] != 0 || result.stderr.length > 0
        raise WinRMUploadError, result.output
      end
    end
  end
end
