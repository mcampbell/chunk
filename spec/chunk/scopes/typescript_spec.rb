# frozen_string_literal: true

RSpec.describe Chunk::Scopes::Typescript do
  subject(:finder) { described_class.new('.ts') }

  let(:sample) { File.read(File.join(__dir__, '../../fixtures/ts/sample.ts'), encoding: Encoding::UTF_8).lines }

  it 'gives only the method for a line in a method' do
    expect(finder.call(sample, 9)).to eq(8..10)
  end

  it 'gives the enclosing method for a line in an anonymous callback' do
    expect(finder.call(sample, 17)).to eq(16..18)
  end

  it 'gives the function for a line in an arrow function stored in a class field' do
    expect(finder.call(sample, 5)).to eq(4..6)
  end

  it 'gives the class for a line in a class field that holds no function' do
    lines = "class A {\n  n = 1;\n  m() {}\n}\n".lines

    expect(finder.call(lines, 2)).to eq(1..4)
  end

  it 'gives nil for an import line, so the next finder of the chain runs' do
    expect(finder.call(sample, 1)).to be_nil
  end

  it 'gives the inner function for a line in a function inside a function' do
    lines = "function outer() {\n  function inner() {\n    x();\n  }\n  y();\n}\n".lines

    expect([finder.call(lines, 3), finder.call(lines, 5)]).to eq([2..4, 1..6])
  end

  it 'reads JSX when the extension is .jsx' do
    lines = "function App() {\n  return <div>{1}</div>;\n}\n".lines

    expect(described_class.new('.jsx').call(lines, 2)).to eq(1..3)
  end

  it 'raises Unreadable for a syntax error' do
    broken = File.read(File.join(__dir__, '../../fixtures/ts/broken.ts')).lines

    expect { finder.call(broken, 1) }.to raise_error(Chunk::Scopes::Unreadable, /expected/)
  end

  it 'raises Unreadable when node is not installed' do
    path = ENV.fetch('PATH')
    ENV['PATH'] = make_dir

    expect { finder.call(sample, 9) }.to raise_error(Chunk::Scopes::Unreadable, /node/)
  ensure
    ENV['PATH'] = path
  end

  # The hunk builder calls with the old file and the new file in turn. Node takes about 0.1 s to start.
  it 'runs the script for the old file and the new file once each, when calls take turns' do
    old_lines = sample.dup
    new_lines = sample.dup
    allow(Open3).to receive(:capture3).and_call_original

    3.times { [old_lines, new_lines].each { finder.call(it, 9) } }

    expect(Open3).to have_received(:capture3).twice
  end
end
