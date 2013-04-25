require 'spec_helper'
describe Iso8601Duration do
  describe '#sec_to_dur' do
    it { Iso8601Duration.sec_to_dur(60).should == 'PT60S' }
    it { Iso8601Duration.sec_to_dur(120).should == 'PT2M' }
    it { Iso8601Duration.sec_to_dur(7200).should == 'PT2H' }
    it { Iso8601Duration.sec_to_dur(86400).should == 'P1D' }
    it { Iso8601Duration.sec_to_dur(604800).should == 'P1W' }
    it { Iso8601Duration.sec_to_dur(597750).should == 'P6DT22H2M30S' }
  end
end