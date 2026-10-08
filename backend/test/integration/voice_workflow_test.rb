require "test_helper"

class VoiceWorkflowTest < ActionDispatch::IntegrationTest
  setup do
    @memory = Memory.create!(person_name: "Mara", title: "A song", story: "Mara sang in the kitchen.")
    @original_voice_service_url = ENV.delete("VOICE_SERVICE_URL")
  end

  teardown do
    ENV["VOICE_SERVICE_URL"] = @original_voice_service_url if @original_voice_service_url
  end

  test "consent is required before a voice profile is created" do
    post "/api/v1/memories/#{@memory.id}/voice", params: { sample: sample_upload }

    assert_response :unprocessable_content
    assert_nil @memory.reload.voice_profile
  end

  test "creates a browser preview profile and speech without provider credentials" do
    post "/api/v1/memories/#{@memory.id}/voice", params: {
      sample: sample_upload,
      consent_confirmed: "true"
    }

    assert_response :created
    assert_equal "browser_preview", response.parsed_body.fetch("provider")
    assert @memory.reload.voice_profile.consent_confirmed?

    post "/api/v1/memories/#{@memory.id}/speech", params: { text: "Remember the summer." }, as: :json

    assert_response :created
    assert_equal "complete", response.parsed_body.fetch("status")
    assert_nil response.parsed_body.fetch("audio_url")
  end

  private

  def sample_upload
    Rack::Test::UploadedFile.new(file_fixture("voice.wav"), "audio/wav")
  end
end
