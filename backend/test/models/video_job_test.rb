require "test_helper"

class VideoJobTest < ActiveSupport::TestCase
  test "requires a known status" do
    memory = Memory.create!(
      person_name: "Mara",
      title: "Garden afternoon",
      story: "The afternoon smelled like mint and rain."
    )

    video_job = memory.video_jobs.build(status: "lost", prompt: "Make it cinematic")

    assert_not video_job.valid?
    assert_includes video_job.errors[:status], "is not included in the list"
  end
end
