# encoding: UTF-8
describe WinRM::Output, unit: true do
  subject { WinRM::Output.new }

  context 'when there is no output' do
    describe '#stdout' do
      it 'is empty' do
        expect(subject.stdout).to be_empty
      end
    end

    describe '#stderr' do
      it 'is empty' do
        expect(subject.stderr).to be_empty
      end
    end

    describe '#output' do
      it 'is empty' do
        expect(subject.output).to be_empty
      end
    end
  end

  context 'when there is only one line' do
    describe '#stdout' do
      it 'is equal to that line' do
        subject[:data] << { stdout: 'foo' }
        expect(subject.stdout).to eq('foo')
      end
    end

    describe '#stderr' do
      it 'is equal to that line' do
        subject[:data] << { stderr: 'foo' }
        expect(subject.stderr).to eq('foo')
      end
    end

    describe '#output' do
      it 'is equal to stdout' do
        subject[:data] << { stdout: 'foo' }
        expect(subject.output).to eq('foo')
      end

      it 'is equal to stderr' do
        subject[:data] << { stderr: 'foo' }
        expect(subject.output).to eq('foo')
      end
    end
  end

  context 'when there is one line of each type' do
    before(:each) do
      subject[:data] << { stdout: 'foo' }
      subject[:data] << { stderr: 'bar' }
    end

    describe '#stdout' do
      it 'is equal to that line' do
        expect(subject.stdout).to eq('foo')
      end
    end

    describe '#stderr' do
      it 'is equal to that line' do
        expect(subject.stderr).to eq('bar')
      end
    end

    describe '#output' do
      it 'is equal to stdout + stderr' do
        expect(subject.output).to eq('foobar')
      end
    end
  end

  context 'when there are multiple lines' do
    before(:each) do
      subject[:data] << { stdout: 'I can have a newline\nanywhere, ' }
      subject[:data] << { stderr: 'I can also have stderr' }
      subject[:data] << { stdout: 'or stdout', stderr: ' and stderr' }
      subject[:data] << {}
      subject[:data] << { stdout: ' or nothing! (above)' }
    end

    describe '#stdout' do
      it 'is equal to that line' do
        expect(subject.stdout).to eq(
          'I can have a newline\nanywhere, or stdout or nothing! (above)')
      end
    end

    describe '#stderr' do
      it 'is equal to that line' do
        expect(subject.stderr).to eq('I can also have stderr and stderr')
      end
    end

    describe '#output' do
      it 'is equal to stdout + stderr' do
        expect(subject.output).to eq(
          'I can have a newline\nanywhere, I can also have stderror stdout ' \
            'and stderr or nothing! (above)')
      end
    end
  end

  pending 'parse CLIXML errors and convert to Strings and/or Exceptions'
end
