# Windows Remote Management (WinRM) for Ruby
[![Build Status](https://travis-ci.org/WinRb/WinRM.svg?branch=master)](https://travis-ci.org/WinRb/WinRM)
[![Gem Version](https://badge.fury.io/rb/winrm.svg)](http://badge.fury.io/rb/winrm)

This is a SOAP library that uses the functionality in Windows Remote
Management(WinRM) to call native object in Windows.  This includes, but is
not limitted to, running batch scripts, powershell scripts and fetching WMI
variables.  For more information on WinRM, please visit Microsoft's WinRM
site: http://msdn.microsoft.com/en-us/library/aa384426(v=VS.85).aspx

## Supported WinRM Versions
WinRM 1.1 is supported, however 2.0 and higher is recommended. [See MSDN](http://technet.microsoft.com/en-us/library/ff520073(v=ws.10).aspx) for information about WinRM versions and supported operating systems.

## Install
`gem install -r winrm` then on the server `winrm quickconfig` as admin

## Example
```ruby
require 'winrm'
endpoint = 'http://mywinrmhost:5985/wsman'
krb5_realm = 'EXAMPLE.COM'
winrm = WinRM::WinRMWebService.new(endpoint, :kerberos, :realm => krb5_realm)
winrm.cmd('ipconfig /all') do |stdout, stderr|
  STDOUT.print stdout
  STDERR.print stderr
end
```

There are various connection types you can specify upon initialization:

It is recommended that you <code>:disable_sspi => true</code> if you are using the plaintext or ssl transport.

#### Plaintext
```ruby
WinRM::WinRMWebService.new(endpoint, :plaintext, :user => myuser, :pass => mypass, :disable_sspi => true)

## Same but force basic authentication:
WinRM::WinRMWebService.new(endpoint, :plaintext, :user => myuser, :pass => mypass, :basic_auth_only => true)
```

#### SSL
```ruby
WinRM::WinRMWebService.new(endpoint, :ssl, :user => myuser, :pass => mypass, :disable_sspi => true)

# Specifying CA path
WinRM::WinRMWebService.new(endpoint, :ssl, :user => myuser, :pass => mypass, :ca_trust_path => '/etc/ssl/certs/cert.pem', :basic_auth_only => true)

# Same but force basic authentication:
WinRM::WinRMWebService.new(endpoint, :ssl, :user => myuser, :pass => mypass, :basic_auth_only => true)

# Basic auth over SSL w/self signed cert
# Enabling no_ssl_peer_verification is not recommended. HTTPS connections are still encrypted,
# but the WinRM gem is not able to detect forged replies or man in the middle attacks.
WinRM::WinRMWebService.new(endpoint, :ssl, :user => myuser, :pass => mypass, :basic_auth_only => true, :no_ssl_peer_verification => true)
```

##### Create a self signed cert for WinRM
You may want to create a self signed certificate for servicing https WinRM connections. First you must install makecert.exe from the Windows SDK, then you can use the following PowerShell script to create a cert and enable the WinRM HTTPS listener.

```powershell
$hostname = $Env:ComputerName
 
C:\"Program Files"\"Microsoft SDKs"\Windows\v7.1\Bin\makecert.exe -r -pe -n "CN=$hostname,O=vagrant" -eku 1.3.6.1.5.5.7.3.1 -ss my -sr localMachine -sky exchange -sp "Microsoft RSA SChannel Cryptographic Provider" -sy 12 "$hostname.cer"
 
$thumbprint = (& ls cert:LocalMachine/my).Thumbprint
$cmd = "winrm create winrm/config/Listener?Address=*+Transport=HTTPS '@{Hostname=`"$hostname`";CertificateThumbprint=`"$thumbprint`"}'"
iex $cmd
```

#### Kerberos
```ruby
WinRM::WinRMWebService.new(endpoint, :kerberos, :realm => 'MYREALM.COM')
```

## Troubleshooting
You may have some errors like ```WinRM::WinRMAuthorizationError```.
You can run the following commands on the server to try to solve the problem:
```
winrm set winrm/config/client/auth @{Basic="true"}
winrm set winrm/config/service/auth @{Basic="true"}
winrm set winrm/config/service @{AllowUnencrypted="true"}
```
You can read more about that on issue [#29](https://github.com/WinRb/WinRM/issues/29)


## Current features

1. GSSAPI support:  This is the default way that Windows authenticates and
   secures WinRM messages. In order for this to work the computer you are
   connecting to must be a part of an Active Directory domain and you must
   have local credentials via kinit. GSSAPI support is dependent on the
   gssapi gem which only supports the MIT Kerberos libraries at this time.

   If you are using this method there is no longer a need to change the
   WinRM service authentication settings. You can simply do a
   'winrm quickconfig' on your server or enable WinRM via group policy and
   everything should be working.

2. Multi-Instance support:  Moving away from Handsoap allows multiple
   instances to be created because the SOAP backend is no longer a Singleton
   type class.

3. 100% Ruby: Nokogiri while faster can present additional frustration for
   users above and beyond what is already required to get WinRM working.
   The goal of this gem is make using WinRM easy. In V2 we plan on making
   the parser swappable in case you really do need the performance.

## Contributing

1. Fork it.
2. Create a branch (git checkout -b my_feature_branch)
3. Run the unit and integration tests (bundle exec rake integration)
4. Commit your changes (git commit -am "Added a sweet feature")
5. Push to the branch (git push origin my_feature_branch)
6. Create a pull requst from your branch into master (Please be sure to provide enough detail for us to cipher what this change is doing)

### Running the tests

We use Bundler to manage dependencies during development.

```
$ bundle install
```

Once you have the dependencies, you can run the unit tests with `rake`:

```
$ bundle exec rake spec
```

To run the integration tests you will need a Windows box with the WinRM service properly configured. Its easiest to use a Vagrant Windows box.

1. Create a Windows VM with WinRM configured (see above).
2. Copy the config-example.yml to config.yml - edit this file with your WinRM connection details.
3. Ensure that the box you are running the test against has a default shell profile (check ~\Documents\WindowsPowerShell).  If any of your shell profiles generate stdout or stderr output, the test validators may get thrown off.
4. Run `bundle exec rake integration`

## WinRM Author
* Twitter: [@zentourist](https://twitter.com/zentourist)
* BLOG:  [http://distributed-frostbite.blogspot.com/](http://distributed-frostbite.blogspot.com/)
* Add me in LinkedIn:  [http://www.linkedin.com/in/danwanek](http://www.linkedin.com/in/danwanek)
* Find me on irc.freenode.net in #ruby-lang (zenChild)

## Maintainers
* Paul Morton (https://github.com/pmorton)
* Shawn Neal (https://github.com/sneal)

[Contributors](https://github.com/WinRb/WinRM/graphs/contributors)
