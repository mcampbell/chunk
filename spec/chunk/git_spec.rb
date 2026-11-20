# frozen_string_literal: true

RSpec.describe Chunk::Git do
  subject(:reader) { described_class.new(repo) }

  let(:repo) { make_repo }

  before do
    commit_file(repo, 'shared.txt', "first\n")
    git(repo, 'switch', '-q', '-c', 'feature')
    commit_file(repo, 'shared.txt', "first\nfrom feature\n")
    git(repo, 'switch', '-q', 'main')
    commit_file(repo, 'base_only.txt', "only on main after the fork\n")
  end

  describe '#diff' do
    it 'shows the PR changes from the merge base, as GitHub does' do
      diff = reader.diff('main', 'feature')

      expect(diff).to include('+from feature')
    end

    # diff2html and the hunk builder read the "a/" and "b/" path prefixes.
    it 'keeps the standard path prefixes when the user config removes them' do
      git(repo, 'config', 'diff.noprefix', 'true')

      expect(reader.diff('main', 'feature')).to include('--- a/shared.txt', '+++ b/shared.txt')
    end

    it 'leaves out changes made on the base branch after the fork' do
      expect(reader.diff('main', 'feature')).not_to include('base_only.txt')
    end

    it 'reports an unknown ref with the git message' do
      expect { reader.diff('main', 'no-such-branch') }
        .to raise_error(Chunk::Error, /no-such-branch/)
    end

    # Git reads "...feature" as "HEAD...feature", so an empty ref would give a wrong diff with no error.
    it 'refuses an empty ref' do
      expect { reader.diff('', 'feature') }.to raise_error(Chunk::Error, /ref/)
      expect { reader.diff('main', " \t") }.to raise_error(Chunk::Error, /ref/)
    end

    it 'does not read a ref as a git option' do
      target = File.join(repo, 'written-by-option.txt')

      expect { reader.diff("--output=#{target}", 'feature') }.to raise_error(Chunk::Error)
      expect(File).not_to exist(target)
    end

    it 'never changes the working tree or the index' do
      File.write(File.join(repo, 'shared.txt'), "uncommitted edit\n")
      File.write(File.join(repo, 'staged.txt'), "staged\n")
      git(repo, 'add', 'staged.txt')
      before = git(repo, 'status', '--porcelain')

      reader.diff('main', 'feature')

      expect(git(repo, 'status', '--porcelain')).to eq(before)
    end
  end
end
