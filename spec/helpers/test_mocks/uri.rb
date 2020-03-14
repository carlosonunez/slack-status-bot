module SpecHelpers
  module TestMocks
    module URI
      def self.generate(base_url, endpoint, params: nil)
        uri = base_url + '/' + endpoint
        if !params.nil?
          return uri + '?' + params.map{|k,v| "#{k}=#{v}"}.join('&')
        end
        return uri
      end
    end
  end
end
