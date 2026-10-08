module LlmServices
  class ClientFactory
    def self.build(provider: ENV.fetch("LLM_PROVIDER", "ollama"))
      case provider.strip.downcase
      when "ollama"
        OllamaClient.new
      when "fireworks"
        FireworksClient.new
      else
        raise ProviderError, "Unsupported LLM provider: #{provider}"
      end
    end
  end
end
