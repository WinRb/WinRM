# encoding: UTF-8
describe 'WinRM options', unit: true do
  let(:subject) { WinRM::WinRMWebService.new('http://localhost:55985/wsman', :plaintext) }

  context 'when operations timeout is set to 60' do
    before(:each) { subject.set_timeout(60) }
    describe '#receive_timeout' do
      it 'is set to 70s' do
        transportclass = subject.instance_variable_get(:@xfer)
        expect(transportclass.receive_timeout).to eql(70)
      end
    end
    describe '#op_timeout' do
      it 'is set to 60s' do
        expect(subject.timeout).to eql('PT60S')
      end
    end
  end

  context 'when operations timeout is set to 30 and receive timeout is set to 120' do
    before(:each) { subject.set_timeout(30, 120) }
    describe '#receive_timeout' do
      it 'is set to 120s' do
        transportclass = subject.instance_variable_get(:@xfer)
        expect(transportclass.receive_timeout).to eql(120)
      end
    end
    describe '#op_timeout' do
      it 'is set to 30s' do
        expect(subject.timeout).to eql('PT30S')
      end
    end
  end

  context 'when max_env_size is set to 614400' do
    before(:each) { subject.max_env_size(614_400) }
    describe '@max_env_sz' do
      it 'is set to 614400' do
        expect(subject.instance_variable_get('@max_env_sz')).to eq(614_400)
      end
    end
  end

  context 'when locale is set to en-CA' do
    before(:each) { subject.locale('en-CA') }
    describe '@locale' do
      it 'is set to en-CA' do
        expect(subject.instance_variable_get('@locale')).to eq('en-CA')
      end
    end
  end

  context 'default' do
    describe '#receive_timeout' do
      it 'should be 3600ms' do
        transportclass = subject.instance_variable_get(:@xfer)
        expect(transportclass.receive_timeout).to eql(3600)
      end
    end
    describe '#timeout' do
      it 'should be 60s' do
        expect(subject.timeout).to eql('PT60S')
      end
    end
    describe '@locale' do
      it 'should be en-US' do
        expect(subject.instance_variable_get('@locale')).to eq('en-US')
      end
    end
    describe '@max_env_sz' do
      it 'should be 153600' do
        expect(subject.instance_variable_get('@max_env_sz')).to eq(153_600)
      end
    end
  end
end
