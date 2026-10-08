require "test_helper"

class LlmServices::ClientFactoryTest < ActiveSupport::TestCase
  test "builds the Ollama client by default" do
    assert_instance_of LlmServices::OllamaClient, LlmServices::ClientFactory.build(provider: "ollama")
  end

  test "rejects an unsupported provider" do
    error = assert_raises(LlmServices::ProviderError) do
      LlmServices::ClientFactory.build(provider: "unknown")
    end

    assert_equal "Unsupported LLM provider: unknown", error.message
  end
end
