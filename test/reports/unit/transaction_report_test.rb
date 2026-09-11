require "test_helper"

# TransactionReport#format_date is the only place in the app that reads a
# raw column out of a dossier result set, so it is the only place that sees
# whatever type the postgres adapter decoded. Rails 6.1's add_pg_decoders
# maps "timestamp" to PG::TextDecoder::TimestampUtc, which 5.1's did not, so
# the value went from String to Time under the upgrade and the old
# DateTime.strptime raised TypeError. These pin both directions.
class TransactionReportTest < ActiveSupport::TestCase

  test "formats the Time the postgres adapter now decodes" do
    report = TransactionReportByType.new(period: "2026-8")

    assert_equal("2026-08-31", report.format_date(Time.utc(2026, 8, 31, 0, 0, 0)))
  end

  test "formats a midnight timestamp as its own day, not the one before" do
    report = TransactionReportByType.new(period: "2026-8")

    # The decoded value carries the database's wall clock with UTC attached.
    # Converting it into a behind-UTC zone before formatting would roll a
    # midnight timestamp back a day, so format_date must not touch the zone.
    Time.use_zone("America/New_York") do
      assert_equal("2026-08-31", report.format_date(Time.utc(2026, 8, 31, 0, 0, 0)))
    end
  end

  test "still formats a String, as the 5.1 adapter supplied" do
    report = TransactionReportByType.new(period: "2026-8")

    assert_equal("2026-08-31", report.format_date("2026-08-31 00:00:00"))
  end

  test "passes a missing date through instead of raising" do
    report = TransactionReportByType.new(period: "2026-8")

    assert_nil(report.format_date(nil))
  end

  # The guard is blank?, not nil?, so an empty string takes the same path.
  # Pinned because the distinction is invisible at the call site and a Time
  # is never blank -- Object#blank? is !self for anything without empty?.
  test "passes an empty date through instead of raising" do
    report = TransactionReportByType.new(period: "2026-8")

    assert_equal("", report.format_date(""))
  end

end
