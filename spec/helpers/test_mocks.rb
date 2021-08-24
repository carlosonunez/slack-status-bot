# frozen_string_literal: true

Dir.glob('./spec/helpers/test_mocks/**').sort.each do |file|
  require file
end
