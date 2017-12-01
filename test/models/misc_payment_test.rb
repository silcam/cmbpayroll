require "test_helper"

describe MiscPayment do
  let(:misc_payment) { MiscPayment.new }

  it "must be valid" do
    value(misc_payment).must_be :valid?
  end
end
