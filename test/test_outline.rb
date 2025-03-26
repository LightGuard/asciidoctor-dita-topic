# frozen_string_literal: true

require 'minitest/autorun'
require_relative 'helper'

class TestOutline < Minitest::Test
  ##
  # Table of Contents (toc) generation test.
  # This does not test if a new file is created, but checks to see if a correct map, with nested topicrefs is created
  def test_toc_generation
    xml = <<~EOS.chomp.to_dita
    :toc:
    = Document Title

    == Section One

    == Section Two

    === Section Three
    EOS

    assert_xpath_count xml, 1, '//map'
    assert_xpath_equal xml, 'Document Title', '//map/title/text()'

    assert_xpath_count xml, 2, '//map/topicref'
    assert_xpath_equal xml, '-_section_three.dita', '//map/topicref[2]/topicref/@href'
  end
end
