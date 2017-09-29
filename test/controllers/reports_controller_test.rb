require "test_helper"
require 'minitest/autorun'

class ReportsControllerTests < ActionDispatch::IntegrationTest

  def test_reports_hash
    @reports = ReportsController::REPORTS
    first_key = @reports.keys.first

    assert(@reports[first_key][:name].is_a?(String))
    assert(@reports[first_key][:instance].is_a?(Proc))
  end

end
