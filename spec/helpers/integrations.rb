# frozen_string_literal: true

Dir.glob('./spec/helpers/integrations/**').sort.each do |file|
  require file
end
