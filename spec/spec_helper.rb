# frozen_string_literal: true

require_relative '../lib/chunk'

# Chunk::Git starts git with this process environment. Keep the user git config out of the specs.
ENV['GIT_CONFIG_GLOBAL'] = File::NULL
ENV['GIT_CONFIG_NOSYSTEM'] = '1'

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end

Dir[File.join(__dir__, 'support', '*.rb')].each { |file| require file }
