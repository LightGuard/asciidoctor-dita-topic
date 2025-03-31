# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require_relative 'helper'

class TestOutline < Minitest::Test

  def teardown
    # clean up the files we created
    File.delete('ditamap.ditamap') if File.exist?('ditamap.ditamap')
    File.delete 'ditamap-test.ditamap' if File.exist?('/tmp/ditamap-test.ditamap')
    File.delete 'ditamap-test.adoc' if File.exist?('/tmp/ditamap-test.adoc')
  end

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

    # We should not have created a separate ditamap
    refute_path_exists 'ditamap.ditamap'
  end

  def test_new_ditamap_name
    adoc = <<~EOS.chomp
      :toc: macro
      = Document Title

      == Section One

      == Section Two

      === Section Three
    EOS

    # Save the adoc file, convert it, check for ditamap with the proper name, cleanup
    Dir.mktmpdir do |dir|
      tmp_adoc_path = "#{dir}/ditamap-test.adoc"
      File.write(tmp_adoc_path, adoc)
      Asciidoctor.convert_file tmp_adoc_path, backend: 'dita-topic', standalone: true, logger: false, doctype: 'article', to_file: "#{dir}/ditamap-test.dita", base_dir: dir
      assert_path_exists "#{dir}/ditamap-test.ditamap"
      # TODO read ditamap and test to make sure it is all there
    end
  end

  def test_new_ditamap_file
    xml = <<~EOS.chomp.to_dita
      :toc: macro
      = Document Title

      == Section One

      == Section Two

      === Section Three
    EOS

    assert_path_exists 'ditamap.ditamap'

    dita_xml = File.read 'ditamap.ditamap'
    assert_xpath_count dita_xml, 1, '/map'
    assert_xpath_equal dita_xml, 'Document Title', '/map/title/text()'

    assert_xpath_count dita_xml, 2, '/map/topicref'
    assert_xpath_equal dita_xml, '-_section_three.dita', '/map/topicref[2]/topicref/@href'
  end
end
