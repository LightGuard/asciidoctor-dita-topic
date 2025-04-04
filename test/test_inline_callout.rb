require 'minitest/autorun'
require_relative 'helper'

class InlineCalloutTest < Minitest::Test
  def test_callout_number_range
    xml = <<~EOF.chomp.to_dita
    ....
    1: <1>
    ....
    ....
    20: <20>
    ....
    ....
    21: <21>
    ....
    ....
    35: <35>
    ....
    ....
    36: <36>
    ....
    ....
    50: <50>
    ....
    EOF

    # Three ranges of symbols are used to cover numbers between 1 and 50:
    assert_xpath_equal xml, '1: &#9312;', '//pre[contains(., "1:")]/text()'
    assert_xpath_equal xml, '20: &#9331;', '//pre[contains(., "20:")]/text()'
    assert_xpath_equal xml, '21: &#12881;', '//pre[contains(., "21:")]/text()'
    assert_xpath_equal xml, '35: &#12895;', '//pre[contains(., "35:")]/text()'
    assert_xpath_equal xml, '36: &#12977;', '//pre[contains(., "36:")]/text()'
    assert_xpath_equal xml, '50: &#12991;', '//pre[contains(., "50:")]/text()'
  end
end
