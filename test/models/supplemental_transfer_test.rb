require "test_helper"
require "logger"

class SupplementalTransferTest < ActiveSupport::TestCase

  test "Presence Validations" do
    luke = employees :Luke

    assert_raises (ActiveRecord::RecordInvalid) {
      SupplementalTransfer.create!(employee: luke)
    }

    assert_nothing_raised {
      SupplementalTransfer.create!(employee: luke, transfer_date: "2018-01-01")
    }
  end

end
