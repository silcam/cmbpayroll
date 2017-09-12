require "test_helper"

class StandardChargeNoteTest < ActiveSupport::TestCase

  test "Valid" do
    assert_raises (ActiveRecord::RecordInvalid){ StandardChargeNote.create!(note: '') }
    assert StandardChargeNote.create!(note: 'Gorilla')
  end
end
