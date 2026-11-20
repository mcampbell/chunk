# frozen_string_literal: true

require_relative '../lib/chunk'

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end

Dir[File.join(__dir__, 'support', '*.rb')].each { |file| require file }
