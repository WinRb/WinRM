# WinRM Gem Changelog

# 1.3.4
- Relaxed version pins on dev dependencies

# 1.3.3
- Fixed issue 133, rwinrm allow hostnames with dashes
- Use duck typing for powershell script read

# 1.3.2
- Add spec.license attribute to gemspec
- Bump RSpec dependency 3.0 to 3.2

# 1.3.1
- Fixed issue 129, long running commands could cause a stackoverflow exception
- Fixed use of sub! in run_command results in spurious capture/replacement of \& sequences
- Fixed issue 124 rwinrm won't take '.' characters in username

# 1.3.0
- Fixed multiple issues with WinRMHTTPTransportError incorrectly being raised
- Refactored and added more unit and integration tests
- Added ability to write to stdin
- Added rwinrm binary to launch remote shell
- Added WINRM_LOG env var to set log level
- Retry Kerberos auth once if 401 response is received
- Remove Savon dependency and use newer versions of underlying dependencies
- Remove Nokogiri dependency and replace with native Ruby XML
- Fixed issue 85, ensure WQL response is not nil
- All WinRM library errors inherit from base class WinRMError
- Integrations tests should now pass on Windows Server 2008+
- Bump Ruby NTLM gem version dependency
- HTTP client receive timeout is now configurable via set_timeout
- Added backwards compatible Output class to make it easier to collect output
- Bumped gssapi dependency from 1.0 to 1.2 and fixed issue 54
- Added Rubocop to build
- Fixed error when commands contain a newline character

# 1.2.0
- Allow user to disable SSL peer ceritifcate validation #44
- Allow commands with "'" chars on Ruby 2.x, fixes #69
- Fixed uninitialized constant Module::Kconv in Ruby 2.x, fixes #65
- Commands with non-ASCII chars should work, #70
