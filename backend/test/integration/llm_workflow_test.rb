require "test_helper"

class LlmWorkflowTest < ActionDispatch::IntegrationTest
  setup do
    @memory = Memory.create!(
      person_name: "Mara",
      title: "Garden afternoon",
      story: "Mara picked mint while rain tapped on the kitchen window."
    )
    @original_llm_provider = ENV["LLM_PROVIDER"]
    ENV["LLM_PROVIDER"] = "ollama"
    @original_ollama_url = ENV["OLLAMA_URL"]
    ENV["OLLAMA_URL"] = "http://127.0.0.1:1"
  end

  teardown do
    ENV["LLM_PROVIDER"] = @original_llm_provider
    ENV["OLLAMA_URL"] = @original_ollama_url
  end

  test "conversation reports an unavailable model without saving a partial exchange" do
    post "/api/v1/memories/#{@memory.id}/conversation",
         params: { message: "What did the garden smell like?" },
         as: :json

    assert_response :service_unavailable
    assert_match "configured language model is unavailable", response.parsed_body.fetch("error_message")
    assert_empty @memory.conversation_messages
  end

  test "video planning reports an unavailable model" do
    post "/api/v1/memories/#{@memory.id}/videos",
         params: { prompt: "Make it warm and gentle." },
         as: :json

    assert_response :service_unavailable
    assert_match "configured language model is unavailable", response.parsed_body.fetch("error_message")
    assert_empty @memory.video_jobs
  end
end
