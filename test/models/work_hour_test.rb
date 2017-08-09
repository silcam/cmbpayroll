require "test_helper"

describe WorkHour do
  let(:work_hour) { WorkHour.new }

  it "must be valid" do
    value(work_hour).must_be :valid?
  end
end
