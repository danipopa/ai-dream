require "test_helper"

class MediaServices::VideoJobPlannerTest < ActiveSupport::TestCase
  test "generates and stores a model-written video outline" do
    memory = Memory.create!(
      person_name: "Mara",
      title: "Garden afternoon",
      story: "Mara picked mint while rain tapped on the kitchen window.",
      photo_paths: ["photos/garden.jpg"]
    )
    llm_client = FakeLlmClient.new("Opening: rain on the window.\nClosing: mint in the garden.")

    job = MediaServices::VideoJobPlanner.new(memory: memory, llm_client: llm_client)
      .create(prompt: "Keep the tone warm.")

    assert_equal "scripting", job.status
    assert_equal "Keep the tone warm.", job.prompt
    assert_equal "Opening: rain on the window.\nClosing: mint in the garden.", job.generated_script
    assert_includes llm_client.messages.dig(1, :content), memory.story
    assert_includes llm_client.messages.dig(1, :content), "1."
  end

  private

  class FakeLlmClient
    attr_reader :messages

    def initialize(response)
      @response = response
    end

    def chat(messages:, **_options)
      @messages = messages
      @response
    end
  end
end
