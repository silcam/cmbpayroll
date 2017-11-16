require "test_helper"

describe PayslipCorrection do
  let(:payslip_correction) { PayslipCorrection.new }

  it "must be valid" do
    value(payslip_correction).must_be :valid?
  end
end
