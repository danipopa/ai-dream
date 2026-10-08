require "json"
require "net/http"
require "openssl"
require "socket"
require "uri"

module LlmServices
  class FireworksClient
    DEFAULT_BASE_URL = "https://api.fireworks.ai/inference/v1"
    DEFAULT_MODEL = "accounts/fireworks/models/glm-5p3-flash"

    def initialize(base_url: ENV.fetch("FIREWORKS_BASE_URL", DEFAULT_BASE_URL),
                   model: ENV.fetch("FIREWORKS_MODEL", DEFAULT_MODEL),
                   api_key: ENV.fetch("FIREWORKS_API_KEY", ""))
      @base_uri = URI.parse(base_url)
      @model = model
      @api_key = api_key.to_s.strip

      unless @base_uri.is_a?(URI::HTTPS) && @base_uri.host.present?
        raise ProviderError, "Fireworks API URL must use HTTPS"
      end
      raise ProviderError, "Fireworks model must be configured" if @model.blank?
      raise ProviderError, "Fireworks API key is not configured" if @api_key.blank?
    rescue URI::InvalidURIError
      raise ProviderError, "Fireworks API URL is invalid"
    end

    def chat(messages:, temperature: 0.5, num_predict: 512)
      request = Net::HTTP::Post.new(endpoint("/chat/completions"))
      request["Authorization"] = "Bearer #{api_key}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(
        model: model,
        messages: messages,
        stream: false,
        temperature: temperature,
        max_tokens: num_predict
      )

      response = perform(request)
      payload = JSON.parse(response.body)
      content = response_content(payload)
      raise ProviderError, "Fireworks returned an empty response" if content.blank?

      content
    rescue JSON::ParserError
      raise ProviderError, "Fireworks returned an invalid response"
    end

    private

    attr_reader :api_key, :base_uri, :model

    def endpoint(path)
      uri = base_uri.dup
      prefix = base_uri.path.sub(%r{/+\z}, "")
      uri.path = "#{prefix}#{path}"
      uri.query = nil
      uri
    end

    def response_content(payload)
      choices = payload.is_a?(Hash) ? payload["choices"] : nil
      first_choice = choices.first if choices.is_a?(Array)
      message = first_choice["message"] if first_choice.is_a?(Hash)
      content = message["content"] if message.is_a?(Hash)

      if content.is_a?(Array)
        content.filter_map { |part| part["text"] if part.is_a?(Hash) }.join.strip
      else
        content.to_s.strip
      end
    end

    def perform(request)
      response = Net::HTTP.start(
        request.uri.host,
        request.uri.port,
        use_ssl: true,
        open_timeout: 10,
        read_timeout: 180,
        write_timeout: 10
      ) { |http| http.request(request) }
      return response if response.is_a?(Net::HTTPSuccess)

      raise ProviderError, "Fireworks returned HTTP #{response.code}"
    rescue Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError => error
      raise ProviderError, "Fireworks is unavailable: #{error.class}"
    end
  end
end
