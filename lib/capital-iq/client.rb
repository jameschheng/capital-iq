module CapitalIQ
  class Client
    attr_reader :cache, :endpoint

    include HTTParty
    format :json

    def initialize(endpoint, username, password, cache_store=nil, cache_prefix="CAPIQ_")
      @auth = {username: username, password: password}
      @endpoint = endpoint
      @cache = Cache.new(cache_store, cache_prefix)
    end

    def base_request(requests, headers = {})
      # default to json since thats the endpoint
      headers["Content-Type"] ||= "application/json"
      
      # build request
      requests = [requests] unless requests.class == Array
      request_array = requests.collect { |r| r.to_hash }
      request_body = {inputRequests: request_array}.to_json

      # send request
      response_data = from_cache(request_body) || self.class.post(
          @endpoint, body: request_body, basic_auth: @auth, ssl_version: :TLSv1_2, headers: headers
      ).parsed_response

      # analyze response
      response = ApiResponse.new(response_data)
      raise ApiError.new(request_body, response_data) if response.has_errors?
      to_cache(request_body, response_data)
      response
    end

    def request(function, identifiers, mnemonics, properties=nil)
      mnemonics = [mnemonics] unless mnemonics.is_a? Enumerable
      identifiers = [identifiers] unless identifiers.is_a? Enumerable
      requests = []
      identifiers.each do |identifier|
        requests.unshift(*mnemonics.collect {|m| CapitalIQ::Request.new(function, identifier, m, properties)})
      end
      base_request(requests)
    end

    def method_missing(meth, *args, &block)
      if meth.to_s =~ /^request_(.+)$/
        function = $1.upcase
        if Functions.all.include?(function)
          request(*([function]+args))
        else
          super
        end
      else
        super
      end
    end

    private

    def to_cache(request_body, response_data)
      return if @cache.nil?
      @cache[cache_key(request_body)] = Zlib::Deflate.deflate(response_data.to_json)
    end

    def from_cache(request_body)
      return nil if @cache.nil?
      result = @cache[cache_key(request_body)]
      return nil if result.nil?
      JSON.parse(Zlib::Inflate.inflate(result))
    end

    def cache_key(request_body)
      Digest::MD5.hexdigest(request_body.to_s)
    end

  end

  # b/w compatibility with 0.07

  Base = Client
end
