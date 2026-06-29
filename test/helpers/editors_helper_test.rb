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
end
