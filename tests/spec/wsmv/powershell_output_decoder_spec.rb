# encoding: UTF-8

require 'winrm/wsmv/powershell_output_decoder'

describe WinRM::WSMV::PowershellOutputDecoder do
  let(:raw_output_with_bom) do
    'AAAAAAAAAAQAAAAAAAAAAAMAAABJAQAAAAQQBABLay89WtMtRYF2oCs2sdOICu2QnGrnUEeforLJOXRvOe+7vzxTPnNv' \
    'bWUgZGF0YV94MDAwRF9feDAwMEFfPC9TPg=='
  end
  let(:expected) { 'some data' }

  subject { described_class.new }

  context 'valid UTF-8 raw output' do
    it 'decodes' do
      expect(subject.decode(raw_output_with_bom)).to eq(expected)
    end
  end
end
