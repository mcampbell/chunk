# frozen_string_literal: true

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

  it 'writes the page for two refs, prints its path, and opens it' do
    status = run_cli('--repo', repo, 'main', 'feature/x')

    expect(status).to eq(0)
    expect(File.read(written_path)).to include('from feature')
    expect(opened).to eq([written_path])
  end

  it 'names the page after the repository and the refs, safe for a file name' do
    run_cli('--repo', repo, 'main', 'feature/x')

    expect(File.basename(written_path)).to eq("#{File.basename(repo)}-main-feature-x.html")
    expect(File.dirname(written_path)).to eq(output_dir)
  end

  it 'uses the current directory when no repository is given' do
    status = Dir.chdir(repo) { run_cli('main', 'feature/x') }

    expect(status).to eq(0)
    expect(File.read(written_path)).to include('from feature')
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
