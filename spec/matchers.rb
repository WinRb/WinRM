require 'rspec/expectations'

module WinRMSpecs
  def self.stdout(output)
    output[:data].collect do |i|
      i[:stdout]
    end.join('\r\n').gsub(/(\\r\\n)+$/, '')
  end

  def self.stderr(output)
    output[:data].collect do |i|
      i[:stderr]
    end.join('\r\n').gsub(/(\\r\\n)+$/, '')
  end

  def self.run_command(service, shell, command)
    command_output = nil
    out_stream = []
    service.run_command(shell, command) do |command_id|
      command_output = service.get_command_output(shell, command_id) do |stdout|
        out_stream << stdout if stdout
      end
    end

    out_stream.join.chomp
  end
end

RSpec::Matchers.define :have_stdout_match do |expected_stdout|
  match do |actual_output|
    expected_stdout.match(WinRMSpecs.stdout(actual_output)) != nil
  end
  failure_message do |actual_output|
    "expected that '#{WinRMSpecs.stdout(actual_output)}' would match #{expected_stdout}"
  end
end

RSpec::Matchers.define :have_remote_file do |expected_file_name|
  match do | remote_file |
    begin
      exists = WinRMSpecs.run_command(remote_file.service, remote_file.shell, "if exist #{expected_file_name} echo true")
      expect(exists).to eql('true'),
        "expected that '#{expected_file_name}' would exist on #{remote_file.service.endpoint}"

      @with_attributes ||= {}
      @with_attributes.each do | name, expected_value |
        cmd = "Get-ItemProperty -Path #{expected_file_name} | Select -ExpandProperty #{name}"
        actual_value = remote_file.service.powershell(cmd).output.strip
        expect(actual_value).to eq(expected_value.to_s),
          "expected #{expected_file_name} to have property #{name} == #{expected_value}, but it was #{actual_value}"
      end
    rescue RSpec::Expectations::ExpectationNotMetError => e
      @failure_reason = e.message
      raise
    end
  end
  chain :with_attributes do |attributes|
    @with_attributes = attributes
  end
  failure_message do |remote_file|
    @failure_reason || "an unexpected error occured while checking for '#{expected_file_name}' on #{remote_file.service.endpoint}"
  end
end

RSpec::Matchers.define :have_same_content do | local_path, remote_path |
  actual_content = nil
  expected_content = File.read(local_path).chomp
  match do | remote_file |
    actual_content = WinRMSpecs.run_command(remote_file.service, remote_file.shell, "type #{remote_path.gsub("/","\\")}").gsub("\r","")
    actual_content == expected_content
  end
  failure_message do | expected_file_content |
    "expected '#{expected_content}' with length #{expected_content.length} to match contents of #{remote_path}: #{actual_content} with length #{actual_content.length}"
  end
end

RSpec::Matchers.define :have_stderr_match do |expected_stderr|
  match do |actual_output|
    expected_stderr.match(WinRMSpecs.stderr(actual_output)) != nil
  end
  failure_message do |actual_output|
    "expected that '#{WinRMSpecs.stderr(actual_output)}' would match #{expected_stderr}"
  end
end

RSpec::Matchers.define :have_no_stdout do
  match do |actual_output|
    stdout = WinRMSpecs.stdout(actual_output)
    stdout == '\r\n' || stdout == ''
  end
  failure_message do |actual_output|
    "expected that '#{WinRMSpecs.stdout(actual_output)}' would have no stdout"
  end
end

RSpec::Matchers.define :have_no_stderr do
  match do |actual_output|
    stderr = WinRMSpecs.stderr(actual_output)
    stderr == '\r\n' || stderr == ''
  end
  failure_message do |actual_output|
    "expected that '#{WinRMSpecs.stderr(actual_output)}' would have no stderr"
  end
end

RSpec::Matchers.define :have_exit_code do |expected_exit_code|
  match do |actual_output|
    expected_exit_code == actual_output[:exitcode]
  end
  failure_message do |actual_output|
    "expected exit code #{expected_exit_code}, but got #{actual_output[:exitcode]}"
  end
end

RSpec::Matchers.define :be_a_uid do
  match do |actual|
    # WinRM1.1 returns uuid's prefixed with 'uuid:' where as later versions do not
    actual != nil && actual.match(/^(uuid:)*\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$/)
  end
  failure_message do |actual|
    "expected a uid, but got '#{actual}'"
  end
end
