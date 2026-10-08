require "test_helper"

class VoiceProfileTest < ActiveSupport::TestCase
  test "requires recorded consent" do
    memory = Memory.create!(person_name: "Mara", title: "A song", story: "Mara sang in the kitchen.")
    profile = memory.build_voice_profile(
      status: "ready",
      provider: "browser_preview",
      sample_path: "/uploads/sample.wav",
      consent_confirmed: false,
      consent_statement: "Permission statement",
      consent_recorded_at: Time.current
    )

    assert_not profile.valid?
    assert_includes profile.errors[:consent_confirmed], "must be accepted"
  end
end
