# encoding: UTF-8
require 'rspec/expectations'

# rspec matchers
RSpec::Matchers.define :have_stdout_match do |expected_stdout|
  match do |actual_output|
    !expected_stdout.match(actual_output.stdout).nil?
  end
  failure_message do |actual_output|
    "expected that '#{actual_output.stdout}' would match #{expected_stdout}"
  end
end

RSpec::Matchers.define :have_stderr_match do |expected_stderr|
  match do |actual_output|
    !expected_stderr.match(actual_output.stderr).nil?
  end
  failure_message do |actual_output|
    "expected that '#{actual_output.stderr}' would match #{expected_stderr}"
  end
end

RSpec::Matchers.define :have_no_stdout do
  match do |actual_output|
    stdout = actual_output.stdout
    stdout == '\r\n' || stdout == ''
  end
  failure_message do |actual_output|
    "expected that '#{actual_output.stdout}' would have no stdout"
  end
end

RSpec::Matchers.define :have_no_stderr do
  match do |actual_output|
    stderr = actual_output.stderr
    stderr == '\r\n' || stderr == ''
  end
  failure_message do |actual_output|
    "expected that '#{actual_output.stderr}' would have no stderr"
  end
end

RSpec::Matchers.define :have_exit_code do |expected_exit_code|
  match do |actual_output|
    expected_exit_code == actual_output.exitcode
  end
  failure_message do |actual_output|
    "expected exit code #{expected_exit_code}, but got #{actual_output.exitcode}"
  end
end

RSpec::Matchers.define :be_a_uid do
  match do |actual|
    # WinRM1.1 returns uuid's prefixed with 'uuid:' where as later versions do not
    actual && actual.to_s.match(/^(uuid:)*\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$/)
  end
  failure_message do |actual|
    "expected a uid, but got '#{actual}'"
  end
end
