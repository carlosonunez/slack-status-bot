# frozen_string_literal: true

Dir.glob('./spec/helpers/receivers/**').sort.each do |file|
  require file
end
