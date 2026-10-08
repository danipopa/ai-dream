require "test_helper"

class ConversationMessageTest < ActiveSupport::TestCase
  test "requires a known speaker" do
    memory = Memory.create!(
      person_name: "Mara",
      title: "Garden afternoon",
      story: "The afternoon smelled like mint and rain."
    )

    message = memory.conversation_messages.build(speaker: "stranger", content: "Hello")

    assert_not message.valid?
    assert_includes message.errors[:speaker], "is not included in the list"
  end
end
