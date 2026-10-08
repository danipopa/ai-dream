require "test_helper"

class ConversationServices::MemoryPersonaResponderTest < ActiveSupport::TestCase
  setup do
    @memory = Memory.create!(
      person_name: "Mara",
      title: "Garden afternoon",
      story: "Mara picked mint while rain tapped on the kitchen window.",
      person_age_at_memory: 42
    )
    @llm_client = FakeLlmClient.new("It sounds like a peaceful afternoon.")
  end

  test "generates an age-aware response grounded in the saved memory" do
    user, response = ConversationServices::MemoryPersonaResponder.new(
      memory: @memory,
      llm_client: @llm_client
    ).reply(user_message: "What did the garden smell like?", age_years: "75")

    assert_equal "user", user.speaker
    assert_equal "memory_person", response.speaker
    assert_equal 75, response.age_years
    assert_equal "It sounds like a peaceful afternoon.", response.content
    assert_equal 2, @memory.conversation_messages.count

    messages = @llm_client.calls.fetch(0).fetch(:messages)
    assert_includes messages.dig(0, :content), "fictionalized"
    assert_includes messages.dig(1, :content), @memory.story
    assert_includes messages.dig(0, :content), "about age 75"
  end

  test "does not save a partial conversation when the model is unavailable" do
    @llm_client.response = -> { raise LlmServices::ProviderError, "offline" }

    assert_raises(LlmServices::ProviderError) do
      ConversationServices::MemoryPersonaResponder.new(
        memory: @memory,
        llm_client: @llm_client
      ).reply(user_message: "Are you there?", age_years: nil)
    end

    assert_empty @memory.conversation_messages
  end

  private

  class FakeLlmClient
    attr_reader :calls
    attr_accessor :response

    def initialize(response)
      @response = response
      @calls = []
    end

    def chat(**arguments)
      calls << arguments
      response.respond_to?(:call) ? response.call : response
    end
  end
end
