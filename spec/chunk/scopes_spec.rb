# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Chunk::Scopes do
  let(:lines) { Array.new(30) { |i| "l#{i + 1}\n" } }

  describe Chunk::Scopes::Fixed do
    subject(:fixed) { described_class.new(10) }

    # Line numbers are primes chosen on purpose, so an off-by-one shows in the result.
    it 'stops at the first line of the file' do
      expect(fixed.call(lines, 3)).to eq(1..13)
    end

    it 'stops at the last line of the file' do
      expect(fixed.call(lines, 29)).to eq(19..30)
    end

    it 'keeps 10 lines on each side in the middle of the file' do
      expect(fixed.call(lines, 17)).to eq(7..27)
    end

    it 'keeps the whole file when the file is shorter than the scope' do
      expect(fixed.call(lines.first(7), 3)).to eq(1..7)
    end
  end

  describe '.finder_for' do
    let(:warnings) { [] }
    let(:nil_finder) { ->(_lines, _line) {} }
    let(:range_finder) { ->(_lines, _line) { 2..4 } }
    let(:bad_finder) { ->(_lines, _line) { raise Chunk::Scopes::Unreadable, 'boom' } }

    def finder(chain)
      described_class.finder_for('a/x.rb', warnings, chains: { '*.rb' => chain })
    end

    describe 'the Ruby chain' do
      # Line 4 is inside an if: the indentation block is 3..5, the method is 2..6.
      let(:ruby) { "class A\n  def two\n    if x\n      2\n    end\n  end\nend\n".lines }

      %w[app/a.rb lib/tasks/x.rake chunk.gemspec config.ru Gemfile Rakefile].each do |path|
        it "gives the method that holds a changed line in #{path}" do
          expect(described_class.finder_for(path, warnings).call(ruby, 4)).to eq(2..6)
        end
      end

      it 'uses the default chain with one warning for a Ruby file with a syntax error' do
        # Two missing ends. The indentation block of line 3 is 2..3.
        broken = "class A\n  def one\n    1\n".lines
        finder = described_class.finder_for('a.rb', warnings)

        expect([finder.call(broken, 3), finder.call(broken, 3)]).to eq([2..3, 2..3])
        expect(warnings.size).to eq(1)
        expect(warnings.first).to start_with('a.rb: ')
      end

      it 'gives 10 lines for a changed line outside each method and class' do
        file = (["require 'x'\n"] + Array.new(30) { "x = #{it}\n" }).freeze

        expect(described_class.finder_for('a.rb', warnings).call(file, 13)).to eq(3..23)
      end
    end

    describe 'the TypeScript and JavaScript chain' do
      let(:source) { "import a from 'a';\nfunction f() {\n  if (a) {\n    a();\n  }\n}\n".lines }

      # Line 4 is inside an if: the indentation block is 3..5, the function is 2..6.
      %w[a.ts b.tsx c.js d.jsx e.mjs f.cjs].each do |path|
        it "gives the function that holds a changed line in #{path}" do
          expect(described_class.finder_for(path, warnings).call(source, 4)).to eq(2..6)
        end
      end

      # TypeScript syntax cannot read this JSX, so the chain must pass the .jsx extension to the script.
      it 'reads JSX in a .jsx file' do
        jsx = "function App() {\n  if (a) {\n    return <div>{a}</div>;\n  }\n}\n".lines

        expect(described_class.finder_for('app.jsx', warnings).call(jsx, 3)).to eq(1..5)
        expect(warnings).to be_empty
      end

      it 'gives 10 lines for a changed line outside each function and class' do
        file = (["import a from 'a';\n"] + Array.new(30) { "let x#{it} = 1;\n" }).freeze

        expect(described_class.finder_for('a.ts', warnings).call(file, 13)).to eq(3..23)
      end
    end

    describe 'the default chain' do
      let(:yaml) { "top:\n  child:\n    leaf: 1\n  other: 2\nnext: 3\n\nlast: 4\n".lines }

      it 'gives the indentation block of a changed line in a YAML file' do
        expect(described_class.finder_for('c.yml', warnings).call(yaml, 3)).to eq(2..3)
      end

      it 'gives the paragraph of a changed line at indentation level 0' do
        expect(described_class.finder_for('c.yml', warnings).call(yaml, 5)).to eq(1..5)
      end
    end

    it 'falls to the next finder when one gives nil' do
      expect(finder([nil_finder, range_finder]).call(lines, 15)).to eq(2..4)
    end

    it 'keeps only the changed line when every finder gives nil' do
      expect(finder([nil_finder]).call(lines, 15)).to eq(15..15)
    end

    it 'falls back to the default chain with one warning, even on two calls' do
      call = finder([bad_finder])
      # The lines have no indentation and no blank line, so the default chain gives the whole file.
      expect(call.call(lines, 17)).to eq(1..30)
      expect(call.call(lines, 3)).to eq(1..30)
      expect(warnings).to eq(['a/x.rb: boom'])
    end
  end
end
