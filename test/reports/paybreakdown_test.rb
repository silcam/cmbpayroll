require "test_helper"

class PayBreakdownTest < ActiveSupport::TestCase

  test "Breakdown" do

    report = PayBreakdownAllReport.new

    bd = { 10000 => 15,
           5000 => 1,
           2000 => 2,
           1000 => 0,
           500 => 0,
           100 => 0,
           50 => 1,
           25 => 0,
           10 => 1,
           5 => 1 }
    assert_equal(bd, report.pay_breakdown(159065))

    bd = { 10000 => 83,
           5000 => 0,
           2000 => 2,
           1000 => 0,
           500 => 1,
           100 => 2,
           50 => 1,
           25 => 1,
           10 => 2,
           5 => 0 }
    assert_equal(bd, report.pay_breakdown(834795))

    bd = { 10000 => 28,
           5000 => 0,
           2000 => 2,
           1000 => 0,
           500 => 1,
           100 => 2,
           50 => 1,
           25 => 1,
           10 => 1,
           5 => 1 }
    assert_equal(bd, report.pay_breakdown(284790))

    bd = { 10000 => 0,
           5000 => 1,
           2000 => 0,
           1000 => 0,
           500 => 0,
           100 => 0,
           50 => 0,
           25 => 0,
           10 => 0,
           5 => 0 }
    assert_equal(bd, report.pay_breakdown(5000))

    bd = { 10000 => 1,
           5000 => 0,
           2000 => 0,
           1000 => 0,
           500 => 0,
           100 => 0,
           50 => 0,
           25 => 0,
           10 => 0,
           5 => 0 }
    assert_equal(bd, report.pay_breakdown(10000))

    bd = { 10000 => 1,
           5000 => 0,
           2000 => 1,
           1000 => 0,
           500 => 0,
           100 => 0,
           50 => 0,
           25 => 0,
           10 => 0,
           5 => 0 }
    assert_equal(bd, report.pay_breakdown(12000))

    bd = { 10000 => 1,
           5000 => 0,
           2000 => 1,
           1000 => 1,
           500 => 0,
           100 => 0,
           50 => 0,
           25 => 0,
           10 => 0,
           5 => 0 }
    assert_equal(bd, report.pay_breakdown(13000))

    bd = { 10000 => 1,
           5000 => 0,
           2000 => 1,
           1000 => 1,
           500 => 1,
           100 => 0,
           50 => 0,
           25 => 0,
           10 => 0,
           5 => 0 }
    assert_equal(bd, report.pay_breakdown(13500))

    bd = { 10000 => 1,
           5000 => 0,
           2000 => 1,
           1000 => 1,
           500 => 1,
           100 => 1,
           50 => 0,
           25 => 0,
           10 => 0,
           5 => 0 }
    assert_equal(bd, report.pay_breakdown(13600))

    bd = { 10000 => 1,
           5000 => 0,
           2000 => 1,
           1000 => 1,
           500 => 1,
           100 => 1,
           50 => 1,
           25 => 0,
           10 => 0,
           5 => 0 }
    assert_equal(bd, report.pay_breakdown(13650))

    bd = { 10000 => 1,
           5000 => 0,
           2000 => 1,
           1000 => 1,
           500 => 1,
           100 => 1,
           50 => 1,
           25 => 1,
           10 => 0,
           5 => 0 }
    assert_equal(bd, report.pay_breakdown(13675))

    bd = { 10000 => 1,
           5000 => 0,
           2000 => 1,
           1000 => 1,
           500 => 1,
           100 => 1,
           50 => 1,
           25 => 1,
           10 => 1,
           5 => 0 }
    assert_equal(bd, report.pay_breakdown(13685))

    bd = { 10000 => 1,
           5000 => 0,
           2000 => 1,
           1000 => 1,
           500 => 1,
           100 => 1,
           50 => 1,
           25 => 1,
           10 => 1,
           5 => 1 }
    assert_equal(bd, report.pay_breakdown(13690))

    bd = { 10000 => 1,
           5000 => 1,
           2000 => 1,
           1000 => 1,
           500 => 1,
           100 => 1,
           50 => 1,
           25 => 1,
           10 => 1,
           5 => 1 }
    assert_equal(bd, report.pay_breakdown(18690))

    bd = { 10000 => 29,
           5000 => 1,
           2000 => 1,
           1000 => 1,
           500 => 0,
           100 => 3,
           50 => 0,
           25 => 1,
           10 => 2,
           5 => 0 }
    assert_equal(bd, report.pay_breakdown(298345))

    bd = { 10000 => 38,
           5000 => 1,
           2000 => 2,
           1000 => 0,
           500 => 1,
           100 => 4,
           50 => 1,
           25 => 1,
           10 => 2,
           5 => 0 }
    assert_equal(bd, report.pay_breakdown(389995))

  end

end
