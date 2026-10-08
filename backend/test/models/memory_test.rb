require "test_helper"

class MemoryTest < ActiveSupport::TestCase
  test "requires core memory details" do
    memory = Memory.new

    assert_not memory.valid?
    assert_includes memory.errors[:person_name], "can't be blank"
    assert_includes memory.errors[:title], "can't be blank"
    assert_includes memory.errors[:story], "can't be blank"
  end
end
