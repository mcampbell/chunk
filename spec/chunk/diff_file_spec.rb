# frozen_string_literal: true

RSpec.describe Chunk::DiffFile do
  let(:repo) { make_repo }
  let(:base_content) { "one\ntwo\nthree\nfour\nfive\n" }

  # Commits the base state, then the head state, and parses the full diff of the two.
  def parse_change(path = 'f.txt', base: base_content, &change)
    commit_file(repo, path, base) if base
    git(repo, 'switch', '-q', '-c', 'feature')
    change.call
    described_class.parse(Chunk::Git.new(repo).full_diff('main', 'feature'))
  end

  def read(path) = File.binread(File.join(repo, path))

  it 'rebuilds a new file' do
    file = parse_change { commit_file(repo, 'new.txt', "a\nb\n") }.first

    expect([file.old_lines, file.new_lines.join]).to eq([[], read('new.txt')])
    expect(file.rows.map(&:new_no)).to eq([1, 2])
    expect(file.rows.map(&:old_no)).to eq([nil, nil])
    expect(file.rows.map(&:kind)).to eq(%i[added added])
  end

  it 'rebuilds a deleted file' do
    file = parse_change { git(repo, 'rm', '-q', 'f.txt') && git(repo, 'commit', '-q', '-m', 'rm') }.first

    expect([file.old_lines.join, file.new_lines]).to eq([base_content, []])
    expect(file.rows.map(&:kind).uniq).to eq([:deleted])
  end

  it 'rebuilds a rename with a change' do
    file = parse_change do
      git(repo, 'mv', 'f.txt', 'g.txt')
      File.write(File.join(repo, 'g.txt'), "one\ntwo\nTHREE\nfour\nfive\n")
      git(repo, 'add', 'g.txt')
      git(repo, 'commit', '-q', '-m', 'rename')
    end.first

    expect([file.old_lines.join, file.new_lines.join]).to eq([base_content, read('g.txt')])
    expect(file.header.join).to include('rename from f.txt', 'rename to g.txt')
    expect(file.rows.map(&:kind)).to eq(%i[context context deleted added context context])
    expect(file.rows.map { |r| [r.old_no, r.new_no] }).to eq([[1, 1], [2, 2], [3, nil], [nil, 3], [4, 4], [5, 5]])
  end

  it 'gives no rows for a rename only' do
    file = parse_change do
      git(repo, 'mv', 'f.txt', 'g.txt')
      git(repo, 'commit', '-q', '-m', 'rename')
    end.first

    expect(file.rows).to be_empty
    expect(file.header.join).to include('rename to g.txt')
  end

  it 'gives no rows for a binary file' do
    file = parse_change('b.bin', base: "a\0b\n") do
      commit_file(repo, 'b.bin', "a\0c\n")
    end.first

    expect(file.rows).to be_empty
    expect(file.header.join).to include('Binary files')
  end

  it 'keeps the missing final newline of the old file' do
    file = parse_change(base: "one\ntwo") { commit_file(repo, 'f.txt', "one\ntwo\nthree\n") }.first

    expect([file.old_lines.join, file.new_lines.join]).to eq(%W[one\ntwo one\ntwo\nthree\n])
    expect(file.rows.select(&:no_newline).map(&:kind)).to eq([:deleted])
  end

  it 'keeps the missing final newline of the new file' do
    file = parse_change(base: "one\ntwo\n") { commit_file(repo, 'f.txt', "one\ntwo\nthree") }.first

    expect([file.old_lines.join, file.new_lines.join]).to eq(%W[one\ntwo\n one\ntwo\nthree])
    expect(file.rows.select(&:no_newline).map(&:kind)).to eq([:added])
  end

  it 'keeps a missing final newline on a context row of both files' do
    file = parse_change(base: "one\ntwo") { commit_file(repo, 'f.txt', "zero\none\ntwo") }.first

    expect([file.old_lines.join, file.new_lines.join]).to eq(%W[one\ntwo zero\none\ntwo])
    expect(file.rows.last).to have_attributes(kind: :context, no_newline: true, text: 'two')
  end

  it 'rebuilds a file with deleted lines only' do
    file = parse_change { commit_file(repo, 'f.txt', "one\nfive\n") }.first

    expect([file.old_lines.join, file.new_lines.join]).to eq([base_content, "one\nfive\n"])
    expect(file.rows.map(&:kind)).to eq(%i[context deleted deleted deleted context])
  end

  it 'splits the diff into one object for each file' do
    files = parse_change do
      commit_file(repo, 'f.txt', "ONE\ntwo\nthree\nfour\nfive\n")
      commit_file(repo, 'h.txt', "new\n")
    end

    expect(files.map { |f| f.header.first }).to eq(["diff --git a/f.txt b/f.txt\n", "diff --git a/h.txt b/h.txt\n"])
  end

  it 'reads more than one hunk in a file' do
    text = "diff --git a/f b/f\n--- a/f\n+++ b/f\n@@ -1,2 +1,2 @@\n-a\n+A\n b\n@@ -9 +9 @@\n-y\n+Y\n"
    file = described_class.parse(text).first

    expect(file.rows.map { |r| [r.kind, r.old_no, r.new_no, r.text] }).to eq(
      [[:deleted, 1, nil, "a\n"], [:added, nil, 1, "A\n"], [:context, 2, 2, "b\n"],
       [:deleted, 9, nil, "y\n"], [:added, nil, 9, "Y\n"]]
    )
  end
end
