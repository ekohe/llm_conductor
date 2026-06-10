# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require_relative 'support'

RSpec.shared_examples 'a store' do
  it 'round-trips raw output' do
    subject.write_raw('run1', 'in1', 'modelA', 'hello')
    expect(subject.read_raw('run1', 'in1', 'modelA')).to eq('hello')
  end

  it 'round-trips parsed output' do
    subject.write_parsed('run1', 'in1', 'modelA', { 'score' => 1 })
    expect(subject.read_parsed('run1', 'in1', 'modelA')).to eq('score' => 1)
  end

  it 'round-trips input data' do
    subject.write_input_data('run1', 'in1', { 'text' => 'hi' })
    expect(subject.read_input_data('run1', 'in1')).to eq('text' => 'hi')
  end

  it 'round-trips the manifest with string keys' do
    subject.write_manifest('run1', { run_id: 'run1', rows: [{ a: 1 }] })
    expect(subject.read_manifest('run1')).to eq('run_id' => 'run1', 'rows' => [{ 'a' => 1 }])
  end

  it 'reports completion only once output exists' do
    expect(subject.completed?('run1', 'in1', 'modelA')).to be(false)
    subject.write_parsed('run1', 'in1', 'modelA', { 'x' => 1 })
    expect(subject.completed?('run1', 'in1', 'modelA')).to be(true)
  end

  it 'returns nil for missing reads' do
    expect(subject.read_raw('run1', 'nope', 'modelA')).to be_nil
    expect(subject.read_parsed('run1', 'nope', 'modelA')).to be_nil
    expect(subject.read_input_data('run1', 'nope')).to be_nil
    expect(subject.read_manifest('nope')).to be_nil
  end
end

RSpec.describe LlmConductor::Eval::Store::InMemory do
  subject { described_class.new }

  it_behaves_like 'a store'
end

RSpec.describe LlmConductor::Eval::Store::FileStore do
  subject(:store) { described_class.new(dir) }

  let(:dir) { Dir.mktmpdir }

  after { FileUtils.remove_entry(dir) }

  it_behaves_like 'a store'

  it 'writes files in the prototype layout and returns the path' do
    path = store.write_parsed('run1', 'in1', 'gemini-2.5-flash', { 'x' => 1 })
    expect(path).to eq(File.join(dir, 'run1', 'in1', 'gemini-2.5-flash.json'))
    expect(File).to exist(path)
  end
end
