require "test_helper"

class EditorsHelperTest < ActionView::TestCase
  include EditorsHelper

  test "render_html_content keeps image alignment class" do
    html = '<p><img src="/uploads/a.png" alt="Example" class="img-align-left"></p>'

    sanitized = render_html_content(html)

    assert_includes sanitized, 'class="img-align-left"'
  end

  test "render_html_content strips unsafe image attributes" do
    html = '<img src="/uploads/a.png" class="img-align-right" onerror="alert(1)">'

    sanitized = render_html_content(html)

    assert_includes sanitized, 'class="img-align-right"'
    refute_includes sanitized, "onerror"
  end

  test "render_html_content keeps image width and height attributes" do
    html = '<img src="/uploads/a.png" width="420" height="280" class="img-align-right">'

    sanitized = render_html_content(html)

    assert_includes sanitized, 'width="420"'
    assert_includes sanitized, 'height="280"'
  end

  test "render_html_content keeps tinymce figure alignment classes" do
    html = '<figure class="image image-style-align-left"><img src="/uploads/a.png" alt="Example"></figure>'

    sanitized = render_html_content(html)

    assert_includes sanitized, "<figure"
    assert_includes sanitized, "image-style-align-left"
  end

  test "render_html_content strips link target attributes" do
    html = '<a href="https://example.com" target="_blank" rel="noopener">Example</a>'

    sanitized = render_html_content(html)

    assert_includes sanitized, 'rel="noopener"'
    refute_includes sanitized, "target="
  end

  test "render_html_content keeps table border and color styling" do
    html = '<table border="1" style="border-color: #ef4444;"><tr><td style="background-color: #fef3c7; color: #1f2937;">Cell</td></tr></table>'

    sanitized = render_html_content(html)

    assert_includes sanitized, '<table border="1"'
    assert_includes sanitized, "border-color"
    assert_includes sanitized, "background-color"
    assert_includes sanitized, "color"
  end

  test "render_html_content keeps span color and text alignment styles" do
    html = '<p style="text-align: center;"><span style="color: #2563eb; background-color: #dbeafe;">Styled text</span></p>'

    sanitized = render_html_content(html)

    assert_includes sanitized, "text-align:center"
    assert_includes sanitized, "<span"
    assert_includes sanitized, "color:#2563eb"
    assert_includes sanitized, "background-color:#dbeafe"
  end

  test "render_html_content keeps table alignment and border attributes" do
    html = '<table border="2" bordercolor="#1d4ed8" cellpadding="8" cellspacing="0" frame="box" rules="all"><tr><td align="right" valign="top" bgcolor="#f8fafc">Cell</td></tr></table>'

    sanitized = render_html_content(html)

    assert_includes sanitized, 'border="2"'
    assert_includes sanitized, 'bordercolor="#1d4ed8"'
    assert_includes sanitized, 'cellpadding="8"'
    assert_includes sanitized, 'cellspacing="0"'
    assert_includes sanitized, 'frame="box"'
    assert_includes sanitized, 'rules="all"'
    assert_includes sanitized, 'align="right"'
    assert_includes sanitized, 'valign="top"'
    assert_includes sanitized, 'bgcolor="#f8fafc"'
  end
end
