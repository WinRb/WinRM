require 'spec_helper'

describe WinRM::Path do
  subject(:rooted_windows_path) { WinRM::Path.new("C:\\test\\test") }
  subject(:relative_windows_path) { WinRM::Path.new("\\test\\test\\set") }
  subject(:unc_path) { WinRM::Path.new("\\\\test\\test\\set") }
  subject(:unix_path) { WinRM::Path.new("C:/test/test") }
  subject(:ugly_path) { WinRM::Path.new("C:/test\\\\test//test/") }
  subject(:naked_root) { WinRM::Path.new("C:") }

  describe 'ugly_path' do
    it { ugly_path.original_path.should =~ /\\\\/ }
    it { ugly_path.original_path.should =~ /\\/ }
    it { ugly_path.original_path.should =~ /\// }
    it { ugly_path.original_path.should =~ /\/\// }
    it { ugly_path.original_path.should =~ /\/$/ }
    it { ugly_path.original_path.should =~ /^C:/ }
  end

  describe '.normalize' do
    it { ugly_path.normalize.should == 'C:/test/test/test' }
    it { relative_windows_path.normalize.should == 'test/test/set'}
  end

  describe '.windows_path' do
    it { ugly_path.windows_path.should == "C:\\test\\test\\test" } 
    it { relative_windows_path.windows_path.should == "test\\test\\set"}
  end

  describe '.unix_path' do
    it { ugly_path.unix_path.should == "C:/test/test/test"}
    it { relative_windows_path.unix_path.should == "test/test/set"}
  end

  describe '.unc?' do
    it { unc_path.unc?.should == true }
    it { ugly_path.unc?.should == false }
    it { relative_windows_path.unc?.should == false }
  end

  describe '.relative?' do
    it { ugly_path.relative?.should == false }
    it { relative_windows_path.relative?.should == true}
    it { unc_path.relative?.should == false}
  end

  describe '.root' do
    it { ugly_path.root.should == 'C' }
    it { relative_windows_path.root.should == nil }
    it { naked_root.root.should == 'C'}
    it { unc_path.root.should == nil }
  end

  describe '.rooted?' do
    it { ugly_path.rooted?.should == true }
    it { relative_windows_path.rooted?.should == false }
    it { naked_root.rooted?.should == true }
    it { unc_path.rooted?.should == false }
  end

  describe '.leaf' do
    it { ugly_path.leaf.should == '/test/test/test'}
    it { relative_windows_path.leaf.should == relative_windows_path.normalize}
  end

  describe '.dirname' do
    it { ugly_path.dirname.should == "C:/test/test" }
    it { relative_windows_path.dirname.should == 'test/test'}
  end

  describe '.basenname' do
    it { rooted_windows_path.basename.should == 'test' }
    it { relative_windows_path.basename.should == 'set'}
  end

  describe '.double_escaped_windows_path' do
    it { ugly_path.double_escaped_windows_path.should == "C:\\\\test\\\\test\\\\test"}
  end

end
