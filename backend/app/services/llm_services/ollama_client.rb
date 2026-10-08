require "json"
require "net/http"
require "socket"
require "uri"

module LlmServices
  class OllamaClient
    def initialize(base_url: ENV.fetch("OLLAMA_URL", "http://ollama:11434"),
                   model: ENV.fetch("OLLAMA_MODEL", "qwen2.5:3b"))
      @base_uri = URI.parse(base_url)
      @model = model

      unless @base_uri.is_a?(URI::HTTP) && @base_uri.host.present? && @model.present?
        raise ProviderError, "Ollama URL and model must be configured"
      end
    rescue URI::InvalidURIError
      raise ProviderError, "Ollama URL is invalid"
    end

    def chat(messages:, temperature: 0.5, num_predict: 512)
      request = Net::HTTP::Post.new(endpoint("/api/chat"))
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(
        model: model,
        messages: messages,
        stream: false,
        options: { temperature: temperature, num_predict: num_predict, num_ctx: 8192 }
      )

      response = perform(request)
      payload = JSON.parse(response.body)
      message = payload.is_a?(Hash) ? payload["message"] : nil
      content = message.is_a?(Hash) ? message["content"].to_s.strip : ""
      raise ProviderError, "Ollama returned an empty response" if content.blank?

      content
    rescue JSON::ParserError
      raise ProviderError, "Ollama returned an invalid response"
    end

    private

    attr_reader :base_uri, :model

    def endpoint(path)
      uri = base_uri.dup
      uri.path = path
      uri.query = nil
      uri
    end

    def perform(request)
      response = Net::HTTP.start(
        request.uri.host,
        request.uri.port,
        use_ssl: request.uri.scheme == "https",
        open_timeout: 5,
        read_timeout: 180,
        write_timeout: 10
      ) { |http| http.request(request) }
      return response if response.is_a?(Net::HTTPSuccess)

      raise ProviderError, "Ollama returned HTTP #{response.code}"
    rescue Timeout::Error, SocketError, SystemCallError, IOError => error
      raise ProviderError, "Ollama is unavailable: #{error.class}"
    end
  end
end
