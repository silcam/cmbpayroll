require "test_helper"

describe Transaction do
  let(:transaction) { Transaction.new }

  it "must be valid" do
    value(transaction).must_be :valid?
  end
end
