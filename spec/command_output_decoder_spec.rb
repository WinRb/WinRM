# encoding: UTF-8

require 'winrm/command_output_decoder'

describe WinRM::CommandOutputDecoder, unit: true do
  let(:raw_output_with_bom) do
    '77u/' \
    'ICAgQ29ubmVjdGlvbi1zcGVjaWZpYyBETlMgU3VmZml4ICAuIDogDQogICBMaW5rLWxvY2FsIElQdjYgQWRkcmVzcyA' \
    'uIC4gLiAuIC4gOiBmZTgwOjo5MTFkOjE2OTQ6NTcwNDo1YjI5JTEyDQogICBJUHY0IEFkZHJlc3MuIC4gLiAuIC4gLi' \
    'AuIC4gLiAuIC4gOiAxMC4wLjIuMTUNCiAgIFN1Ym5ldCBNYXNrIC4gLiAuIC4gLiAuIC4gLiAuIC4gLiA6IDI1NS4yN' \
    'TUuMjU1LjANCiAgIERlZmF1bHQgR2F0ZXdheSAuIC4gLiAuIC4gLiAuIC4gLiA6IDEwLjAuMi4yDQoNClR1bm5lbCBh' \
    'ZGFwdGVyIGlzYXRhcC57RjBENTY2RDgtNzlCMS00QUYwLUJENUQtMkM5RkVEOEI3MTE3fToNCg0KICAgTWVkaWEgU3R' \
    'hdGUgLiAuIC4gLiAuIC4gLiAuIC4gLiAuIDogTWVkaWEgZGlzY29ubmVjdGVkDQogICBDb25uZWN0aW9uLXNwZWNpZm' \
    'ljIEROUyBTdWZmaXggIC4gOiANCg0KVHVubmVsIGFkYXB0ZXIgVGVyZWRvIFR1bm5lbGluZyBQc2V1ZG8tSW50ZXJmY' \
    'WNlOg0KDQogICBDb25uZWN0aW9uLXNwZWNpZmljIEROUyBTdWZmaXggIC4gOiANCiAgIElQdjYgQWRkcmVzcy4gLiAu' \
    'IC4gLiAuIC4gLiAuIC4gLiA6IDIwMDE6MDo5ZDM4OjZhYmQ6NGJiOjI4YjU6ZjVmZjpmZGYwDQogICBMaW5rLWxvY2F' \
    'sIElQdjYgQWRkcmVzcyAuIC4gLiAuIC4gOiBmZTgwOjo0YmI6MjhiNTpmNWZmOmZkZjAlMTQNCiAgIERlZmF1bHQgR2' \
    'F0ZXdheSAuIC4gLiAuIC4gLiAuIC4gLiA6IDo6DQo='
  end
  let(:expected) do
    "   Connection-specific DNS Suffix  . : \r\n   Link-local IPv6 Address . . . . . : fe80::911" \
    "d:1694:5704:5b29%12\r\n   IPv4 Address. . . . . . . . . . . : 10.0.2.15\r\n   Subnet Mask ." \
    " . . . . . . . . . . : 255.255.255.0\r\n   Default Gateway . . . . . . . . . : 10.0.2.2\r\n" \
    "\r\nTunnel adapter isatap.{F0D566D8-79B1-4AF0-BD5D-2C9FED8B7117}:\r\n\r\n   Media State . ." \
    " . . . . . . . . . : Media disconnected\r\n   Connection-specific DNS Suffix  . : \r\n\r\nT" \
    "unnel adapter Teredo Tunneling Pseudo-Interface:\r\n\r\n   Connection-specific DNS Suffix  " \
    ". : \r\n   IPv6 Address. . . . . . . . . . . : 2001:0:9d38:6abd:4bb:28b5:f5ff:fdf0\r\n   Li" \
    "nk-local IPv6 Address . . . . . : fe80::4bb:28b5:f5ff:fdf0%14\r\n   Default Gateway . . . ." \
    " . . . . . : ::\r\n"
  end
  subject { described_class.new }
  context 'valid UTF-8 raw output' do
    it 'decodes' do
      expect(subject.decode(raw_output_with_bom)).to eq(expected)
    end
  end
end
