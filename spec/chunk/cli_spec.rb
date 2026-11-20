# frozen_string_literal: true

require 'json'
require 'stringio'

RSpec.describe Chunk::Cli do
  let(:repo) { make_repo }
  let!(:output_dir) { File.join(make_repo, 'pages') }
  let(:out) { StringIO.new }
  let(:err) { StringIO.new }
  let(:opened) { [] }
  let(:opener) { ->(path) { opened << path } }

  before do
    commit_file(repo, 'a.txt', "first\n")
    git(repo, 'switch', '-q', '-c', 'feature/x')
    commit_file(repo, 'a.txt', "first\nfrom feature\n")
  end

  def run_cli(*argv, open: opener)
    described_class.new(argv, env: { 'CHUNK_OUTPUT_DIR' => output_dir }, out:, err:, opener: open).run
  end

  def written_path = out.string.chomp

  # The browser ends a script element at the first "</script", so read the data the same way.
  def page_diff(html) = JSON.parse(html[%r{<script type="application/json" id="chunk-diff">(.*?)</script}m, 1])

  it 'writes the page for two refs, prints its path, and opens it' do
    status = run_cli('--repo', repo, 'main', 'feature/x')

    expect(status).to eq(0)
    expect(File.read(written_path, encoding: Encoding::UTF_8)).to include('from feature')
    expect(opened).to eq([written_path])
  end

  # Blank lines after rows 23 and 37 (primes) make the paragraph around row 30.
  it 'shows the paragraph that holds each change in a plain text file' do
    rows = lambda do |changed|
      (1..60).map do |row|
        (row == 30 && changed ? "row 30 changed\n" : "row #{row}\n") + ([23, 37].include?(row) ? "\n" : '')
      end.join
    end
    git(repo, 'switch', '-q', 'main')
    commit_file(repo, 'long.txt', rows.call(false))
    git(repo, 'switch', '-q', '-c', 'long')
    commit_file(repo, 'long.txt', rows.call(true))

    run_cli('--repo', repo, 'main', 'long')
    shown = page_diff(File.read(written_path, encoding: Encoding::UTF_8)).lines.grep(/ row \d+$/).map { it[/\d+/].to_i }

    expect(shown.minmax).to eq([24, 37])
  end

  it 'shows only the method that holds a change in a Ruby file' do
    methods = lambda { |two|
      "class A\n  def one\n    1\n  end\n\n  def two\n    #{two}\n  end\n\n  def three\n    3\n  end\nend\n"
    }
    git(repo, 'switch', '-q', 'main')
    commit_file(repo, 'a.rb', methods.call(2))
    git(repo, 'switch', '-q', '-c', 'ruby')
    commit_file(repo, 'a.rb', methods.call(22))

    run_cli('--repo', repo, 'main', 'ruby')
    diff = page_diff(File.read(written_path, encoding: Encoding::UTF_8))

    # A context line is one space, then the line with its 2-space indent.
    expect(diff).to include('   def two', '+    22')
    expect(diff).not_to include('def one', 'def three')
  end

  it 'shows a warning on the page for a file that its finder cannot read' do
    unreadable = ->(_, _) { raise Chunk::Scopes::Unreadable, 'parser failed' }
    stub_const('Chunk::Scopes::CHAINS', { '*.txt' => [unreadable] })

    run_cli('--repo', repo, 'main', 'feature/x')

    expect(File.read(written_path, encoding: Encoding::UTF_8)).to include('a.txt: parser failed')
  end

  it 'names the page after the repository and the refs, safe for a file name' do
    run_cli('--repo', repo, 'main', 'feature/x')

    expect(File.basename(written_path)).to eq("#{File.basename(repo)}-main-feature-x.html")
    expect(File.dirname(written_path)).to eq(output_dir)
  end

  it 'uses the current directory when no repository is given' do
    status = Dir.chdir(repo) { run_cli('main', 'feature/x') }

    expect(status).to eq(0)
    expect(File.read(written_path, encoding: Encoding::UTF_8)).to include('from feature')
  end

  it 'still succeeds when the page cannot be opened' do
    status = run_cli('--repo', repo, 'main', 'feature/x', open: ->(_path) { false })

    expect(status).to eq(0)
    expect(err.string).to include('could not open')
  end

  it 'fails with the git message for an unknown ref' do
    status = run_cli('--repo', repo, 'main', 'no-such-branch')

    expect(status).to eq(1)
    expect(err.string).to include('no-such-branch')
    expect(opened).to be_empty
  end

  it 'fails with the git message for a directory that is not a repository' do
    expect(run_cli('--repo', make_dir, 'main', 'feature/x')).to eq(1)
    expect(err.string).to start_with('chunk: ').and include('not a git repository')
  end

  it 'fails with the git message for a directory that does not exist' do
    expect(run_cli('--repo', File.join(make_dir, 'missing'), 'main', 'feature/x')).to eq(1)
    expect(err.string).to start_with('chunk: ').and include('cannot change to')
  end

  context 'when the output directory cannot be made' do
    let(:output_dir) do
      blocker = File.join(make_repo, 'a-file')
      File.write(blocker, '')
      File.join(blocker, 'pages')
    end

    it 'fails with a short message and no stack trace' do
      expect(run_cli('--repo', repo, 'main', 'feature/x')).to eq(1)
      expect(err.string).to match(/\Achunk: .*File exists/)
    end
  end

  it 'fails with a short message and no stack trace when git is not installed' do
    path = ENV.fetch('PATH')
    ENV['PATH'] = make_dir

    expect(run_cli('--repo', repo, 'main', 'feature/x')).to eq(1)
    expect(err.string).to match(/\Achunk: .*git/)
  ensure
    ENV['PATH'] = path
  end

  it 'shows the usage for a wrong argument count' do
    expect(run_cli('main')).to eq(2)
    expect(run_cli('main', 'feature/x', 'extra')).to eq(2)
    expect(err.string).to include('Usage: chunk')
  end

  it 'names the unknown option, then shows the usage' do
    expect(run_cli('--nope', 'main', 'feature/x')).to eq(2)
    expect(err.string).to include('invalid option: --nope').and include('Usage: chunk')
  end

  it 'names the option that has no value, then shows the usage' do
    expect(run_cli('main', 'feature/x', '--repo')).to eq(2)
    expect(err.string).to include('missing argument: --repo').and include('Usage: chunk')
  end
end
