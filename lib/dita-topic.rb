# A custom AsciiDoc converter that generates individual DITA topics
# Copyright (C) 2024 Jaromir Hradilek

# MIT License
#
# Permission  is hereby granted,  free of charge,  to any person  obtaining
# a copy of  this software  and associated documentation files  (the "Soft-
# ware"),  to deal in the Software  without restriction,  including without
# limitation the rights to use,  copy, modify, merge,  publish, distribute,
# sublicense, and/or sell copies of the Software,  and to permit persons to
# whom the Software is furnished to do so,  subject to the following condi-
# tions:
#
# The above copyright notice  and this permission notice  shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS",  WITHOUT WARRANTY OF ANY KIND,  EXPRESS
# OR IMPLIED,  INCLUDING BUT NOT LIMITED TO  THE WARRANTIES OF MERCHANTABI-
# LITY,  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT
# SHALL THE AUTHORS OR COPYRIGHT HOLDERS  BE LIABLE FOR ANY CLAIM,  DAMAGES
# OR OTHER LIABILITY,  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM,  OUT OF OR IN CONNECTION WITH  THE SOFTWARE  OR  THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

# frozen_string_literal: true

module Asciidoctor
class DitaTopic < Asciidoctor::Converter::Base
  NAME = 'dita-topic'
  register_for NAME

  def initialize *args
    super
    outfilesuffix '.dita'

    # Enable floating and block titles by default:
    @titles_allowed = true
  end

  def convert_document node
    # Check if floating and block titles are enabled:
    @titles_allowed = false if (node.attr 'dita-topic-titles') == 'strict'

    # Check if a specific topic type is provided:
    if (value = node.attr 'dita-topic-type') =~ /^(concept|reference|task)$/
      type = value
      body = (type == 'task') ? 'taskbody' : %(#{type[0,3]}body)
    else
      type = 'topic'
      body = 'body'
    end

    # Check if the modular documentation content type is specified:
    outputclass = (node.attr? '_mod-docs-content-type') ? %( outputclass="#{(node.attr '_mod-docs-content-type').downcase}") : ''

    # Return the XML output:
    <<~EOF.chomp
    <?xml version='1.0' encoding='utf-8' ?>
    <!DOCTYPE #{type} PUBLIC "-//OASIS//DTD DITA #{type.capitalize}//EN" "#{type}.dtd">
    <#{type}#{compose_id (node.id or node.attributes['docname'])}#{outputclass}>
    <title>#{node.doctitle}</title>
    <#{body}>
    #{node.content}
    </#{body}>
    </#{type}>
    EOF
  end

  def convert_admonition node
    # NOTE: Unlike admonitions in AsciiDoc, the <note> element in DITA
    # cannot have its own <title>. Admonition titles are therefore not
    # preserved.

    # Issue a warning if the admonition has a title:
    if node.title?
      logger.warn "#{NAME}: Admonition titles not supported in DITA"
    end

    # Return the XML output:
    <<~EOF.chomp
    <note type="#{node.attr 'name'}">
    #{node.content}
    </note>
    EOF
  end

  def convert_audio node
    # Issue a warning if audio content is present:
    logger.warn "#{NAME}: Audio macro not supported"
    return ''
  end

  def convert_colist node
    # Reset the counter:
    number = 0

    # Open the table:
    result = ['<table>']
    result << %(<tgroup cols="2">)
    result << %(<colspec colwidth="#{node.attr 'labelwidth', 15}*" />)
    result << %(<colspec colwidth="#{node.attr 'itemwidth', 85}*" />)
    result << %(<tbody>)

    # Process individual list items:
    node.items.each do |item|
      # Increment the counter:
      number += 1

      # Open the table row:
      result << %(<row>)

      # Compose the callout number:
      result << %(<entry>#{compose_circled_number number}</entry>)

      # Check if description contains multiple block elements:
      if item.blocks
        result << %(<entry>)
        result << %(<p>#{item.text}</p>)
        result << item.content
        result << %(</entry>)
      else
        result << %(<entry>#{item.text}</entry>)
      end

      # Close the row:
      result << %(</row>)
    end

    # Close the table:
    result << %(</tbody>)
    result << %(</tgroup>)
    result << %(</table>)

    # Return the XML output:
    result.join LF
  end

  def convert_dlist node
    # Check if a different list style is set:
    return compose_horizontal_dlist node if node.style == 'horizontal'
    return compose_qanda_dlist node if node.style == 'qanda'

    # Open the definition list:
    result = ['<dl>']

    # Process individual list items:
    node.items.each do |terms, description|
      # Open the definition entry:
      result << %(<dlentry>)

      # Process individual terms:
      terms.each do |item|
        result << %(<dt>#{item.text}</dt>)
      end

      # Check if the term description is specified:
      if description
        # Check if the description contains multiple block elements:
        if description.blocks?
          result << %(<dd>)
          result << %(<p>#{description.text}</p>) if description.text?
          result << description.content
          result << %(</dd>)
        else
          result << %(<dd>#{description.text}</dd>)
        end
      end

      # Close the definition entry:
      result << %(</dlentry>)
    end

    # Close the definition list:
    result << '</dl>'

    # Return the XML output:
    add_block_title (result.join LF), node.title, 'dlist'
  end

  def convert_example node
    <<~EOF.chomp
    <example#{compose_id node.id}>
    #{node.title ? %(<title>#{node.title}</title>\n) : ''}#{node.content}
    </example>
    EOF
  end

  def convert_floating_title node
    # NOTE: Unlike AsciiDoc, DITA does not have a dedicated element for
    # floating titles. As a workaround, I decided to use a paragraph with
    # the outputclass attribute.

    # Issue a warning if floating titles are disabled:
    unless @titles_allowed
      logger.warn "#{NAME}: Floating titles not supported in DITA"
      return ''
    end

    # Return the XML output:
    %(<p outputclass="title sect#{node.level}"><b>#{node.title}</b></p>)
  end

  # FIXME: Add support for additional attributes.
  def convert_image(node)
    # Check if scale, height, and width exist
    scale = node.attr('scale') || 100
    height = node.attr('height')
    width = node.attr('width')

    # Construct the attributes string based on if scale, height, and width exist
    attributes = "scale=\"#{scale}\""
    attributes += " height=\"#{height}\"" if height
    attributes += " width=\"#{width}\"" if width

    # Check if the image has a title specified
    if node.title?
      <<~EOF.chomp
      <fig>
        <title>#{node.title}</title>
        <image href="#{node.image_uri(node.attr 'target')}" placement="break" #{attributes}>
          <alt>#{node.alt}</alt>
        </image>
      </fig>
      EOF
    else
      <<~EOF.chomp
      <image href="#{node.image_uri(node.attr 'target')}" placement="break" #{attributes}>
        <alt>#{node.alt}</alt>
      </image>
      EOF
    end
  end

  def convert_inline_anchor node
    # Determine the type of the anchor:
    case node.type
    when :link
      # Compose an external link:
      %(<xref href="#{node.target}" scope="external">#{node.text}</xref>)
    when :xref
      # NOTE: While AsciiDoc is happy to reference an ID that is not
      # defined in the same AsciiDoc file, DITA requires the topic ID as
      # part of the reference. As this script does not have direct access
      # to the topic IDs of external files and to avoid performance issues
      # I do not want to process them from this script, I choose to issue a
      # warning so that the user can resolve the problem.

      # Determine whether the cross reference links to a file path or an ID:
      if (path = node.attributes['path'])
        # Issue a warning if the cross reference includes an ID:
        logger.warn "#{NAME}: Possible invalid reference: #{node.target}" if node.target.include? '#'

        # Compose a cross reference:
        %(<xref href="#{node.target}">#{node.text || path}</xref>)
      else
        # Issue a warning as the cross reference is unlikely to work:
        logger.warn "#{NAME}: Possible invalid reference: #{node.target}"

        # Compose the cross reference:
        node.text ? %(<xref href="#{node.target}">#{node.text}</xref>) : %(<xref href="#{node.target}" />)
      end
    when :ref
      # NOTE: DITA does not have a dedicated element for inline anchors or
      # a direct equivalent of the <span> element from HTML. The solution
      # below is the least invasive way I could find to achieve the
      # equivalent behavior.

      # Compose an inline anchor:
      %(<i id="#{node.id}" />)
    when :bibref
      # NOTE: DITA does not have a dedicated element for inline anchors or
      # a direct equivalent of the <span> element from HTML. The solution
      # below is the least invasive way I could find to achieve the
      # equivalent behavior.

      # Compose a bibliographic reference:
      %(<i id="#{node.id}" />[#{node.reftext || node.id}])
    else
      # Issue a warning if an unknown anchor type is present:
      logger.warn "#{NAME}: Unknown anchor type: #{node.type}"
      ''
    end
  end

  def convert_inline_break node
    # NOTE: Unlike AsciiDoc, DITA does not support inline line breaks.

    # Issue a warning if an inline line break is present:
    logger.warn "#{NAME}: Inline breaks not supported in DITA"

    # Return the XML output:
    %(#{node.text}<!-- break -->)
  end

  def convert_inline_button node
    %(<uicontrol outputclass="button">#{node.text}</uicontrol>)
  end

  def convert_inline_callout node
    compose_circled_number node.text.to_i
  end

  # FIXME: Add support for footnoteref equivalent.
  def convert_inline_footnote node
    %(<fn>#{node.text}</fn>)
  end

  # FIXME: Add support for additional attributes.
  def convert_inline_image node
    %(<image href="#{node.image_uri node.target}" placement="inline"><alt>#{node.alt}</alt></image>)
  end

  def convert_inline_indexterm node
    # Issue a warning if an inline index term is present:
    logger.warn "#{NAME}: Inline index terms not implemented"
    return ''
  end

  def convert_inline_kbd node
    # Check if there is more than one key:
    if (keys = node.attr 'keys').size == 1
      %(<uicontrol outputclass="key">#{keys[0]}</uicontrol>)
    else
      %(<uicontrol outputclass="key">#{keys.join '</uicontrol>+<uicontrol outputclass="key">'}</uicontrol>)
    end
  end

  def convert_inline_menu node
    # Compose the markup for the menu:
    menu = %(<uicontrol>#{node.attr 'menu'}</uicontrol>)

    # Compose the markup for possible submenus:
    submenus = (not (node.attr 'submenus').empty?) ? %(<uicontrol>#{(node.attr 'submenus').join '</uicontrol><uicontrol>'}</uicontrol>) : ''

    # Compose the markup for the menu item:
    menuitem = (node.attr 'menuitem') ? %(<uicontrol>#{node.attr 'menuitem'}</uicontrol>) : ''

    # Return the XML output:
    %(<menucascade>#{menu}#{submenus}#{menuitem}</menucascade>)
  end

  def convert_inline_quoted node
    # Determine the inline markup type:
    case node.type
    when :emphasis
      %(<i>#{node.text}</i>)
    when :strong
      %(<b>#{node.text}</b>)
    when :monospaced
      %(<tt>#{node.text}</tt>)
    when :superscript
      %(<sup>#{node.text}</sup>)
    when :subscript
      %(<sub>#{node.text}</sub>)
    when :double
      %(&#8220;#{node.text}&#8221;)
    when :single
      %(&#8216;#{node.text}&#8217;)
    else
      node.text
    end
  end

  def convert_listing node
    # Check the listing style:
    if node.style == 'source'
      # Check whether the source language is defined:
      language = (node.attributes.key? 'language') ? %( outputclass="language-#{node.attributes['language']}") : ''

      # Compose the XML output:
      result = <<~EOF.chomp
      <codeblock#{language}>
      #{node.content}
      </codeblock>
      EOF
    else
      # Compose the XML output:
      result = <<~EOF.chomp
      <screen>
      #{node.content}
      </screen>
      EOF
    end

    # Return the XML output:
    add_block_title result, node.title, 'listing'
  end

  def convert_literal node
    # Compose the XML output:
    result = <<~EOF.chomp
    <pre>
    #{node.content}
    </pre>
    EOF

    # Return the XML output:
    add_block_title result, node.title, 'literal'
  end

  def convert_olist node
    # Open the ordered list:
    result = ['<ol>']

    # Process individual list items:
    node.items.each do |item|
      # Check if the list item contains multiple block elements:
      if item.blocks?
        result << %(<li>)
        result << %(<p>#{item.text}</p>)
        result << item.content
        result << %(</li>)
      else
        result << %(<li>#{item.text}</li>)
      end
    end

    # Close the ordered list:
    result << '</ol>'

    # Return the XML output:
    add_block_title (result.join LF), node.title, 'olist'
  end

  # FIXME: This is not the top priority.
  def convert_open node
    ''
  end

  def convert_page_break node
    # NOTE: Unlike AsciiDoc, DITA does not support page breaks.

    # Issue a warning if a page break is present:
    logger.warn "#{NAME}: Page breaks not supported in DITA"

    # Return the XML output:
    %(<p outputclass="page-break"></p>)
  end

  def convert_paragraph node
    add_block_title %(<p>#{node.content}</p>), node.title, 'paragraph'
  end

  def convert_preamble node
    node.content
  end

  def convert_quote node
    # Check if the author is defined:
    author = (node.attr? 'attribution') ? %(\n<p>&#8212; #{node.attr 'attribution'}</p>) : ''

    # Check if the citation source is defined:
    source = (node.attr? 'citetitle') ? %(\n<cite>#{node.attr 'citetitle'}</cite>) : ''

    # Check if the content contains multiple block elements:
    if node.content_model == :compound
      <<~EOF.chomp
      <lq>
      #{compose_floating_title node.title}#{node.content}#{author}#{source}
      </lq>
      EOF
    else
      <<~EOF.chomp
      <lq>
      #{compose_floating_title node.title}<p>#{node.content}</p>#{author}#{source}
      </lq>
      EOF
    end
  end

  def convert_section node
    # NOTE: Unlike sections in AsciiDoc, the <section> element in DITA
    # cannot be nested. Consequently, converting AsciiDoc files that do
    # contain nested subsections will result in invalid markup.
    #
    # I explored the possibility to use the <topic> element instead as it
    # can be nested, but that presents a problem with closing the <body>
    # element of the parent <topic>. As only a very small number of
    # AsciiDoc modules contain nested subsections, I chose the simple
    # markup.

    # Issue a warning if there are nested sections:
    logger.warn "#{NAME}: Nesting of sections not supported in DITA" if node.level > 1

    # Return the XML output:
    <<~EOF.chomp
    <section#{compose_id node.id}>
    <title>#{node.title}</title>
    #{node.content}
    </section>
    EOF
  end

  def convert_sidebar node
    # NOTE: Unlike AsciiDoc, DITA does not provide markup for a sidebar. As
    # a workaround, I decided to use a div with the outputclass attribute.

    # Check if the content contains multiple block elements:
    if node.content_model == :compound
      <<~EOF.chomp
      <div outputclass="sidebar">
      #{compose_floating_title node.title}#{node.content}
      </div>
      EOF
    else
      <<~EOF.chomp
      <div outputclass="sidebar">
      #{compose_floating_title node.title}<p>#{node.content}</p>
      </div>
      EOF
    end
  end

  def convert_stem node
    # Issue a warning if a STEM content is present:
    logger.warn "#{NAME}: STEM support not implemented"
    return ''
  end

  def convert_table node
    # Open the table:
    result = ['<table>']

    # Check if the title is specified:
    result << %(<title>#{node.title}</title>) if node.title?

    # Define the table properties and open the tgroup:
    result << %(<tgroup cols="#{node.attr 'colcount'}">)

    # Define column properties:
    node.columns.each do |column|
      result << %(<colspec colname="col_#{column.attr 'colnumber'}" colwidth="#{column.attr ((node.attr? 'width') ? 'colabswidth' : 'colpcwidth')}*"/>)
    end

    # Process each table section (header, body, and footer):
    node.rows.to_h.each do |type, rows|
      # Skip empty sections:
      next if rows.empty?

      # Issue a warning if a table footer is present:
      if type == :foot
        logger.warn "#{NAME}: Table footers not supported in DITA"
        next
      end

      # Open the section:
      result << %(<t#{type}>)

      # Process each row:
      rows.each do |row|
        # Open the row:
        result << %(<row>)

        # Process each cell:
        row.each do |cell|
          # Check if the cell spans multiple columns:
          colspan = cell.colspan ? %( namest="col_#{colnum = cell.column.attr 'colnumber'}" nameend="col_#{colnum + cell.colspan - 1}") : ''

          # Check if the cell spans multiple rows:
          rowspan = cell.rowspan ? %( morerows="#{cell.rowspan - 1}") : ''

          # Compose the entry tag:
          entry_tag = %(entry#{colspan}#{rowspan})

          # Determine the formatting of the entry:
          if type == :head
            result << %(<#{entry_tag}>#{cell.text}</entry>)
            next
          end
          case cell.style
          when :asciidoc
            result << %(<#{entry_tag}>#{cell.content}</entry>)
          when :literal
            result << %(<#{entry_tag}><pre>#{cell.text}</pre></entry>)
          else
            result << %(<#{entry_tag}>)
            cell.content.each do |line|
              result << %(<p>#{line}</p>)
            end
            result << %(</entry>)
          end
        end

        # Close the row:
        result << %(</row>)
      end

      # Close the section:
      result << %(</t#{type}>)
    end

    # Close the table:
    result << %(</tgroup>)
    result << %(</table>)

    # Return the XML output:
    result.join LF
  end

  def convert_thematic_break node
    # NOTE: Unlike AsciiDoc, DITA does not support thematic breaks.

    # Issue a warning if a thematic break is present:
    logger.warn "#{NAME}: Thematic breaks not supported in DITA"

    # Return the XML output:
    %(<p outputclass="thematic-break"></p>)
  end

  def convert_ulist node
    # Open the unordered list:
    result = ['<ul>']

    # Process individual list items:
    node.items.each do |item|
      # Check if the list item is part of a checklist:
      unless item.attr? 'checkbox'
        check_box = ''
      else
        check_box = (item.attr? 'checked') ? '&#10003; ' : '&#10063; '
      end

      # Check if the list item contains multiple block elements:
      if item.blocks?
        result << %(<li>)
        result << %(<p>#{check_box}#{item.text}</p>)
        result << item.content
        result << %(</li>)
      else
        result << %(<li>#{check_box}#{item.text}</li>)
      end
    end

    # Close the unordered list:
    result << '</ul>'

    # Returned the XML output:
    add_block_title (result.join LF), node.title, 'ulist'
  end

  def convert_verse node
    # Check if the author is defined:
    author = (node.attr? 'attribution') ? %(\n&#8212; #{node.attr 'attribution'}) : ''

    # Check if the citation source is defined:
    source = (node.attr? 'citetitle') ? %(\n<cite>#{node.attr 'citetitle'}</cite>) : ''

    # Return the XML output:
    <<~EOF.chomp
    <lines>
    #{node.content}#{author}#{source}
    </lines>
    EOF
  end

  def convert_video node
    # Issue a warning if video content is present:
    logger.warn "#{NAME}: Video macro not supported"
    return ''
  end

  def compose_qanda_dlist node
    # Open the ordered list:
    result = ['<ol>']

    # Process individual list items:
    node.items.each do |terms, description|
      # Open the list item:
      result << %(<li>)

      # Process individual terms:
      terms.each do |item|
        result << %(<p outputclass="question"><i>#{item.text}</i></p>)
      end

      # Check if the term description is specified:
      if description
        result << %(<p>#{description.text}</p>)
        result << description.content if description.blocks?
      end

      # Close the list item:
      result << %(</li>)
    end

    # Close the ordered list:
    result << '</ol>'

    # Return the XML output:
    add_block_title (result.join LF), node.title, 'qanda'
  end

  def compose_horizontal_dlist node
    # Open the table:
    result = ['<table>']
    result << %(<tgroup cols="2">)
    result << %(<colspec colwidth="#{node.attr 'labelwidth', 15}*" />)
    result << %(<colspec colwidth="#{node.attr 'itemwidth', 85}*" />)
    result << %(<tbody>)

    # Process individual list items:
    node.items.each do |terms, description|
      # Open the table row:
      result << %(<row>)

      # Check the number of terms to process:
      if terms.count == 1
        result << %(<entry><b>#{terms[0].text}</b></entry>)
      else
        # Process individual terms:
        result << %(<entry>)
        terms.each do |item|
          result << %(<p><b>#{item.text}</b></p>)
        end
        result << %(</entry>)
      end

      # Check if the term description is specified:
      if description
        # Check if the description contains multiple block elements:
        if description.blocks?
          result << %(<entry>)
          result << %(<p>#{description.text}</p>) if description.text?
          result << description.content
          result << %(</entry>)
        else
          result << %(<entry>#{description.text}</entry>) if description.text?
        end
      end

      # Close the table row:
      result << %(</row>)
    end

    # Close the table:
    result << %(</tbody>)
    result << %(</tgroup>)
    result << %(</table>)

    # Return the XML output:
    add_block_title (result.join LF), node.title, 'horizontal'
  end

  # Method aliases

  alias convert_embedded content_only
  alias convert_pass content_only
  alias convert_toc skip

  # Helper methods

  def add_block_title content, title, context='wrapper'
    # NOTE: Unlike AsciiDoc, DITA does not support titles assigned to
    # certain block elements. As a workaround, I decided to use a paragraph
    # with the outputclass attribute and wrap the block in a div element.

    # Check if the title is defined:
    return content unless title

    # Issue a warning if block titles are disabled:
    unless @titles_allowed
      logger.warn "#{NAME}: Block titles not supported in DITA"
      return content
    end

    # Return the XML output:
    <<~EOF.chomp
    <div outputclass="#{context}">
    <p outputclass="title"><b>#{title}</b></p>
    #{content}
    </div>
    EOF
  end

  def compose_floating_title title
    # NOTE: Unlike AsciiDoc, DITA does not support floating titles or
    # titles assigned to certain block elements. As a workaround, I decided
    # to use a paragraph with the outputclass attribute.

    # Check if the title is defined:
    return '' unless title

    # Issue a warning if floating titles are disabled:
    unless @titles_allowed
      logger.warn "#{NAME}: Floating titles not supported in DITA"
      return ''
    end

    # Return the XML output:
    %(<p outputclass="title"><b>#{title}</b></p>\n)
  end

  def compose_id id
    id ? %( id="#{id}") : ''
  end

  def compose_circled_number number
    # Verify the number is in a supported range:
    if number < 1 || number > 50
      logger.warn "#{NAME}: Callout number not in range between 1 and 50"
      return number
    end

    # Compose the XML entity:
    if number < 21
      %(&##{9311 + number};)
    elsif number < 36
      %(&##{12860 + number};)
    else
      %(&##{12941 + number};)
    end
  end
end
end
