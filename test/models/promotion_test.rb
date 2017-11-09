require "test_helper"

describe Promotion do
  let(:promotion) { Promotion.new }

  it "must be valid" do
    value(promotion).must_be :valid?
  end
end
