# encoding: UTF-8
describe WinRM::Output do
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
        subject << { stdout: 'foo' }
        expect(subject.stdout).to eq('foo')
      end
    end

    describe '#stderr' do
      it 'is equal to that line' do
        subject << { stderr: 'foo' }
        expect(subject.stderr).to eq('foo')
      end
    end

    describe '#output' do
      it 'is equal to stdout' do
        subject << { stdout: 'foo' }
        expect(subject.output).to eq('foo')
      end

      it 'is equal to stderr' do
        subject << { stderr: 'foo' }
        expect(subject.output).to eq('foo')
      end
    end
  end

  context 'when there is one line of each type' do
    before(:each) do
      subject << { stdout: 'foo' }
      subject << { stderr: 'bar' }
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
      subject << { stdout: 'I can have a newline\nanywhere, ' }
      subject << { stderr: 'I can also have stderr' }
      subject << { stdout: 'or stdout', stderr: ' and stderr' }
      subject << {}
      subject << { stdout: ' or nothing! (above)' }
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

  describe '#exitcode' do
    let(:exitcode) { 0 }

    context 'when a valid exit code is set' do
      it 'sets the exit code' do
        subject.exitcode = exitcode
        expect(subject.exitcode).to eq exitcode
      end
    end

    context 'when an invalid exit code is set' do
      let(:exitcode) { 'bad' }

      it 'sets the exit code' do
        expect { subject.exitcode = exitcode }.to raise_error WinRM::InvalidExitCode
      end
    end
  end
end
