# Windows Remote Management (WinRM) for Ruby

This is a SOAP library that uses the functionality in Windows Remote
Management(WinRM) to call native object in Windows.  This includes, but is
not limitted to, running batch scripts, powershell scripts and fetching WMI
variables.  For more information on WinRM, please visit Microsoft's WinRM
site: http://msdn.microsoft.com/en-us/library/aa384426(v=VS.85).aspx

# Quick Start

## WQL/WMI Query
```ruby
require 'winrm'
client = WinRM::Client.new('localhost', user: 'vagrant', pass: 'vagrant')
processes = client.wql("Select * from Win32_Process")
client.disconnect
```

## Executing a process
```ruby
require 'winrm'
client = WinRM::Client.new('localhost', user: 'vagrant', pass: 'vagrant')
return_code, output_streams = client.cmd('dir')
client.disconnect
```

## Executing powershell
```ruby
require 'winrm'
client = WinRM::Client.new('localhost', user: 'vagrant', pass: 'vagrant')
return_code, output_streams = client.powershell("get-childitem C:\")
client.disconnect
```

# Advanced Topics
TODO: _See the Wiki_

# Contributing
1. Fork it.
2. Create a branch (git checkout -b my_feature_branch)
3. Add test coverage and fix issues until the tests pass
3. Commit your changes (git commit -am "Added a sweet feature")
4. Push to the branch (git push origin my_feature_branch)
5. Create a pull requst from your branch into master (Please be sure to provide enough detail for us to cipher what this change is doing)