require 'spec_helper'

require 'bwoken'
require 'bwoken/script'
require 'bwoken/device'

module Bwoken
  class Simulator; end
end

describe Bwoken::Script do

  before { subject.formatter = mock('formatter') }

  describe '#run' do
    let(:exit_status) { 0 }
    before do
      subject.formatter.stub(:format).and_return(exit_status)
      subject.formatter.stub(:before_script_run)
    end

    it 'outputs that a script is about to run' do
      subject.path = 'path'
      subject.formatter.should_receive(:before_script_run).with('path')
      Open3.stub(:popen3)
      subject.stub(:cmd)
      subject.run
    end

    it 'runs with popen3' do
      subject.stub(:cmd).and_return('cmd')
      Open3.should_receive(:popen3).with('cmd').and_yield('in', 'out', 'err', 'wait_thr')
      subject.run
    end

    context 'when passing' do
      it 'does not raise a ScriptFailedError' do
        Open3.stub(:popen3).and_yield(*%w(in out err thr))
        subject.stub(:cmd)
        expect { subject.run }.not_to raise_error
      end
    end

    context 'when failing' do
      let(:exit_status) { 1 }

      it 'raises a ScriptFailedError' do
        Open3.stub(:popen3).and_yield(*%w(in out err thr))
        subject.stub(:cmd)
        expect { subject.run }.to raise_error(Bwoken::ScriptFailedError)
      end
    end

    it 'formats the output with the bwoken formatter' do
      subject.formatter.should_receive(:format).with("a\nb\nc").and_return(0)
      subject.stub(:cmd)

      Open3.stub(:popen3).and_yield('', "a\nb\nc", '', '')

      subject.run
    end
  end

  describe '#env_variables' do
    it 'returns a hash with UIASCRIPT set to #path' do
      Bwoken.stub(:results_path => 'foo')
      subject.path = 'bar'
      subject.env_variables['UIASCRIPT'].should == '"bar"'
    end

    it 'returns a hash with UIARESULTSPATH set to Bwoken.results_path' do
      Bwoken.stub(:results_path => 'foo')
      subject.path = 'bar'
      subject.env_variables['UIARESULTSPATH'].should == '"foo"'
    end

  end

  describe '#env_variables_for_cli' do
    it 'preps the variables for cli use' do
      subject.path = 'foo'
      Bwoken.stub(:results_path => 'bar')

      allowed = ['-e UIASCRIPT "foo" -e UIARESULTSPATH "bar"', '-e UIARESULTSPATH "bar" -e UIASCRIPT "foo"']
      subject.env_variables_for_cli.should be_in(allowed)
    end
  end

  describe '.trace_file_path' do
    it 'points to the trace path inside <bwoken_tmp>' do
      tmp_path = stub_out(Bwoken, :tmp_path, 'bazzle')
      subject.class.trace_file_path.should == "#{tmp_path}/trace"
    end

  end

  describe '#cmd' do
    # WORKING: (Doesn't seems to use the same trace file)
    # instruments -w "iPhone 5s (8.1 Simulator)" -t Automation build/iphonesimulator/BwokenTestApp.app -D integration/tmp/trace -e UIASCRIPT integration/tmp/javascript/iphone/example.js -e UIARESULTSPATH integration/tmp/results

    # This one has been working for me:
    # instruments -t Automation -D integration/tmp/trace -w "iPhone 5s (8.1 Simulator)" build/iphonesimulator/BwokenTestApp.app -e UIASCRIPT integration/tmp/javascript/iphone/example.js -e UIARESULTSPATH integration/tmp/results

    let!(:trace_file_path) { stub_out(subject.class, :trace_file_path, 'trace_file_path') }
    let!(:env_variables_for_cli) { stub_out(subject, :env_variables_for_cli, 'baz') }

    let(:uuid) { 'abcdef1234567890' }
    let(:device_id) { 'iPhone\s5s\s\(.*?\)' }
    let(:app_dir) { 'bar' }
    let(:want_simulator) { true }
    let(:regexp) { /instruments\s+-t\sAutomation\s+-D\s"#{trace_file_path}"\s+-w\s"#{expected_device_flag_regexp}"\s+"#{app_dir}"\s+"#{env_variables_for_cli}"/x }

    before do
      subject.app_dir = app_dir
      subject.simulator = want_simulator
    end

    context 'when a device is connected' do
      before { Bwoken::Device.stub(:uuid => uuid) }
      let(:want_simulator) { false }
      let(:expected_device_flag_regexp) { "#{uuid}" }

      its(:cmd) { should match regexp }
    end

    context 'when a device is not connected' do
      before { Bwoken::Device.stub(:uuid => device_id) }
      let(:expected_device_flag_regexp) { "#{device_id}" }

      its(:cmd) { should match regexp }
    end
  end

end
