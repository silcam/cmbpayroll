require "test_helper"

describe Vacation do
  let(:vacation) { Vacation.new }

  it "must be valid" do
    value(vacation).must_be :valid?
  end
end
