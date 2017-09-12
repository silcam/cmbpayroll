require "test_helper"

describe Holiday do
  let(:holiday) { Holiday.new }

  it "must be valid" do
    value(holiday).must_be :valid?
  end
end
