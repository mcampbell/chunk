# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'tmpdir'

# Builds throw-away git repositories for specs. It never touches a real repository.
module GitRepoHelper
  ISOLATED_ENV = {
    'GIT_CONFIG_NOSYSTEM' => '1',
    'GIT_CONFIG_GLOBAL' => File::NULL,
    'GIT_AUTHOR_NAME' => 'spec', 'GIT_AUTHOR_EMAIL' => 'spec@example.com',
    'GIT_COMMITTER_NAME' => 'spec', 'GIT_COMMITTER_EMAIL' => 'spec@example.com'
  }.freeze

  def make_dir
    dir = Dir.mktmpdir('chunk-spec')
    @made_repos = [*@made_repos, dir]
    dir
  end

  def make_repo
    dir = make_dir
    git(dir, 'init', '-q', '-b', 'main')
    dir
  end

  def git(dir, *args)
    out, err, status = Open3.capture3(ISOLATED_ENV, 'git', '-C', dir, *args)
    raise "git #{args.join(' ')} failed: #{err}" unless status.success?

    out
  end

  def commit_file(dir, path, content, message = "change #{path}")
    full = File.join(dir, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, content)
    git(dir, 'add', path)
    git(dir, 'commit', '-q', '-m', message)
  end

  def remove_made_repos
    Array(@made_repos).each { |dir| FileUtils.remove_entry(dir) }
  end
end

RSpec.configure do |config|
  config.include GitRepoHelper
  config.after { remove_made_repos }
end
