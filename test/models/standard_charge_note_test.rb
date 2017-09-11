require "test_helper"

describe StandardChargeNote do
  let(:standard_charge_note) { StandardChargeNote.new }

  it "must be valid" do
    value(standard_charge_note).must_be :valid?
  end
end
