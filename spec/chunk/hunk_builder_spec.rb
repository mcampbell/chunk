# frozen_string_literal: true

RSpec.describe Chunk::HunkBuilder do
  let(:row) { Chunk::DiffFile::Row }
  let(:header) { ["diff --git a/f b/f\n", "--- a/f\n", "+++ b/f\n"] }

  # Builds rows from a pattern: c context, + added, - deleted. Text is the row index.
  def rows_for(pattern)
    old = new = 0
    pattern.chars.each_with_index.map do |char, idx|
      old += 1 unless char == '+'
      new += 1 unless char == '-'
      kind = { 'c' => :context, '+' => :added, '-' => :deleted }.fetch(char)
      row.new(kind, (old unless char == '+'), (new unless char == '-'), "t#{idx}\n", false)
    end
  end

  def build(pattern, finder)
    described_class.new(finder).build(Chunk::DiffFile.new(header, rows_for(pattern)))
  end

  def single = ->(_, num) { num..num }

  it 'passes a file with no rows through' do
    expect(build('', single)).to eq(header.join)
  end

  it 'gives two hunks for two far changes' do
    text = build('cc+cccccc+cc', ->(_, num) { (num - 1)..num })

    expect(text).to eq("#{header.join}@@ -2,1 +2,2 @@\n t1\n+t2\n@@ -8,1 +9,2 @@\n t8\n+t9\n")
  end

  it 'gives one hunk when spans touch' do
    text = build('cc+c+cc', ->(_, num) { (num - 1)..(num + 1) })

    expect(text.scan(/^@@.*$/)).to eq(['@@ -2,3 +2,5 @@'])
  end

  it 'builds a deleted-only change' do
    expect(build('c-c', single)).to eq("#{header.join}@@ -2,1 +1,0 @@\n-t1\n")
  end

  it 'gives -a,0 for a pure insertion, with a the line before' do
    expect(build('c+c', single)).to eq("#{header.join}@@ -1,0 +2,1 @@\n+t1\n")
  end

  # A formatter run or a lock file can change every line of a large file. This took 140 s before the fix.
  it 'builds a file with 20,000 changed lines in a short time' do
    file = Chunk::DiffFile.new(header, rows_for('-+' * 20_000))

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    described_class.new(Chunk::Scopes::Fixed.new(10)).build(file)
    seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

    expect(seconds).to be < 2
  end

  context 'with a real repo' do
    let(:repo) { make_repo }
    let(:base) { (1..30).map { |n| "line #{n}\n" }.join }

    def apply_check(text, *flags)
      git(repo, 'switch', '-q', '--detach', git(repo, 'merge-base', 'main', 'feature').strip)
      _, err, status = Open3.capture3(GitRepoHelper::ISOLATED_ENV, 'git', '-C', repo, 'apply', '--check', *flags, '-',
                                      stdin_data: text)
      [status.exitstatus, err]
    end

    def rebuilt(finder)
      diff = Chunk::Git.new(repo).full_diff('main', 'feature')
      Chunk::DiffFile.parse(diff).map { |file| described_class.new(finder).build(file) }.join
    end

    def feature(base_files = { 'f.txt' => base }, &change)
      base_files.each { |path, content| commit_file(repo, path, content) }
      git(repo, 'switch', '-q', '-c', 'feature')
      change.call
    end

    def edit(path, content) = commit_file(repo, path, content, 'edit')

    def middle_change = edit('f.txt', base.sub("line 15\n", "LINE 15\n"))

    [
      ['a new file', ->(t) { t.edit('n.txt', "a\nb\n") }],
      ['a deleted file', ->(t) { t.git(t.repo, 'rm', '-q', 'f.txt') && t.git(t.repo, 'commit', '-q', '-m', 'rm') }],
      ['a change in the middle', lambda(&:middle_change)],
      ['no newline at the end of the new file', ->(t) { t.edit('f.txt', "#{t.base}tail") }],
      ['deleted lines only', ->(t) { t.edit('f.txt', t.base.sub("line 10\nline 11\n", '')) }]
    ].each do |name, change|
      # A one-line scope gives hunks with no context, which git applies only with --unidiff-zero.
      { 'a 2-line scope' => [Chunk::Scopes::Fixed.new(2), []],
        'a one-line scope' => [->(_, num) { num..num }, ['--unidiff-zero']] }.each do |scope, (finder, flags)|
        it "applies the rebuilt diff for #{name}, with #{scope}" do
          feature { change.call(self) }
          expect(apply_check(rebuilt(finder), *flags)).to eq([0, ''])
        end
      end
    end

    it 'applies the rebuilt diff when the old file has no newline at the end' do
      feature('f.txt' => "a\nb\nc") { edit('f.txt', "a\nb\nc\nd\n") }

      expect(apply_check(rebuilt(Chunk::Scopes::Fixed.new(2)))).to eq([0, ''])
    end

    it 'applies the rebuilt diff for a rename with a change' do
      feature do
        git(repo, 'mv', 'f.txt', 'g.txt')
        File.write(File.join(repo, 'g.txt'), base.sub("line 15\n", "LINE 15\n"))
        git(repo, 'add', 'g.txt')
        git(repo, 'commit', '-q', '-m', 'rename')
      end

      expect(apply_check(rebuilt(Chunk::Scopes::Fixed.new(2)))).to eq([0, ''])
    end

    it 'keeps the header only for a rename only' do
      feature do
        git(repo, 'mv', 'f.txt', 'g.txt')
        git(repo, 'commit', '-q', '-m', 'rename')
      end

      expect(rebuilted = rebuilt(Chunk::Scopes::Fixed.new(2))).to eq(Chunk::Git.new(repo).full_diff('main', 'feature'))
      expect(rebuilted).not_to include('@@')
    end

    it 'keeps the header only for a binary file' do
      feature('b.bin' => "a\0b\n") { edit('b.bin', "a\0c\n") }

      expect(rebuilt(Chunk::Scopes::Fixed.new(2))).to eq(Chunk::Git.new(repo).full_diff('main', 'feature'))
    end
  end
end
