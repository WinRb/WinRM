# encoding: UTF-8
# This test may only be meaningful with kerberos auth
# Against server 2012, a kerberos connection will require reauth (get a 401)
# if there are no requests for >= 15 seconds

describe 'Verify kerberos will reauth when necessary', kerberos: true do
  before(:all) do
    @winrm = winrm_connection
  end

  it 'work with a 18 second sleep' do
    ps_command = 'Start-Sleep -s 18'
    output = @winrm.run_powershell_script(ps_command)
    output[:exitcode].should == 0
  end
end
