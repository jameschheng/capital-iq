module CapitalIQ
  class ApiError < StandardError
    attr_reader :response_data, :request_body
    def initialize(request_body, response_data)
      @request_body = request_body
      @response_data = response_data
      super("Capital IQ API returned an error. Request content: #{request_body.to_json} Response content: #{response_data.to_json}")
    end

    def inspect
      {response_data: self.response_data}.to_json
    end
  end
end
