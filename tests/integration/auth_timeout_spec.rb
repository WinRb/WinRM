# encoding: UTF-8
require_relative 'spec_helper'

# This test may only be meaningful with kerberos auth
# Against server 2012, a kerberos connection will require reauth (get a 401)
# if there are no requests for >= 15 seconds

describe 'Verify kerberos will reauth when necessary', kerberos: true do
  before(:all) do
    @powershell = winrm_connection.shell(:powershell)
  end

  it 'work with a 18 second sleep' do
    ps_command = 'Start-Sleep -s 18'
    output = @powershell.run(ps_command)
    expect(output.exitcode).to eq(0)
  end
end
