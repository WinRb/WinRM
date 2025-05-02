# WinRM Gem Changelog

# 2.3.9
* Fix snakecase `NoMethodError` by @ripa1995 in https://github.com/WinRb/WinRM/pull/347

# 2.3.8
* Add cert_store option by @ussu in https://github.com/WinRb/WinRM/pull/330

# 2.3.7
* Add ruby-3.1 test by @skeshari12 in https://github.com/WinRb/WinRM/pull/332
* move from travis to GH actions and test ruby 3.1 by @mwrock in https://github.com/WinRb/WinRM/pull/335
* Add rexml as an explicit dependency for Ruby 3.x by @postmodern in https://github.com/WinRb/WinRM/pull/334
* Adding user-agent option by @laxa in https://github.com/WinRb/WinRM/pull/337
* Update CI to use ruby 3.X by @fwininger in https://github.com/WinRb/WinRM/pull/343
* Create thread in shell finalizer by @akihikodaki in https://github.com/WinRb/WinRM/pull/339

# 2.3.6
- Add compatibility with ruby 3.0.0

# 2.3.5
- Do not print debug msg about trouble getting MaxEnvelopeSizekb when succesful
- Do not cleanup command if there is no shell
- Optimize our requires
- Fix typo in error message

# 2.3.4
- Fix ErrorRecord.invocation crash when InvocationInfo is empty

# 2.3.3
- Replace erubis with erubi

# 2.3.2
- Fix Kerberos decryption corruption

# 2.3.1
- Limit the files that are shipped in the gem artifact
- Use peer_cert for validation to prevent validating the signing cert

# 2.3.0
- Fixes rwinrm command
- Use pack('S*') instead of .chr so full utf-16 can be supported
- Omi Server compatibility fixes

# 2.2.3
- Revert change made in 2.2.2 that retries network errors in Close and cleanup

# 2.2.2
- Update PSRP buffer size
- Close and cleanup should retry on error and never raise net errors

# 2.2.1
- Ignore error 2150858843 during shell closing

# 2.2.0
- Allow run_wql to accept custom namespace
- Allow enumeration of WQL result sets

# 2.1.3
- Ignore WSManFault 2150858843 during command cleanup
- Uns `Integer` in place of `Fixnum` to remove deprecation warnings in ruby 2.4

# 2.1.2
- Fix kerberos transport

# 2.1.1
- Fix rendering of powershell output with non ascii UTF-8 characters emitted from executables

# 2.1.0
- Expose shell options when creating a winrm shell

# 2.0.3
- Do not swallow exit codes from executables

# 2.0.2
- Constrain to rubyntlm `>= 0.6.1` to avoid mutating frozen strings
- When using certificate authentication, do not validate presense of user and password
- Handle failed `PIPELINE_STATE` messages so that `throw` errors are not swallowed

# 2.0.1
- Fixed Powershell shell leakage when not explicitly closed
- Fixed cmd commands with responses that extend beyond one stream

# 2.0.0
- Cleaned up API and implemented Powershell Remoting Protocol (PSRP) for all powershell calls.

# 1.8.1
- Http receive timeout should always be equal to 10 seconds greater than the winrm operation timeout and not default to one hour

# 1.8.0
- Add certificate authentication

# 1.7.3
- Open a new shell if the current shell has been deleted

# 1.7.2
- Fix regression where BOM appears in 2008R2 output and is not stripped

# 1.7.1
- Fix OS version comparisons for Windows 10 using `Gem::Version` instead of strings

# 1.7.0
- Bump rubyntlm gem to 0.6.0 to get channel binding support for HTTPS fixing connections to endoints with `CbtHardeningLevel` set to `Strict`
- Fix for parsing binary data in command output

# 1.6.1
- Use codepage 437 by default on os versions older than Windows 7 and Windows Server 2008 R2

# 1.6.0
- Adding `:negotiate` transport providing NTLM/Negotiate encryption of WinRM requests and responses
- Removed dependency on UUIDTools gem
- Extending accepted error codes for retry behavior to include `Errno::ETIMEDOUT`
- Correct deprecation warning for WinRMWebService.run_powershell_script

# 1.5.0
- Deprecating `WinRM::WinRMWebService` methods `cmd`, `run_cmd`, `powershell`, and `run_powershell_script` in favor of the `run_cmd` and `run_powershell_script` methods of the `WinRM::CommandExecutor` class. The `CommandExecutor` allows multiple commands to be run from the same WinRM shell providing a significant performance improvement when issuing multiple calls.
- Added an `:ssl_peer_fingerprint` option to be used instead of `:no_ssl_peer_verification` and allows a specific certificate to be verified.
- Opening a winrm shell is retriable with configurable delay and retry limit.
- Logging apends to `stdout` by default and can be replaced with a logger from a consuming application.

# 1.4.0
- Added WinRM::Version so the gem version is available at runtime for consumers.

# 1.3.6
- Remove BOM from response (Issue #159) added by Windows 2008R2

# 1.3.5
- Widen logging version constraints to include 2.0
- Use codepage 65001 (UTF-8)

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
