require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  def image_upload
    Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/main-image.png"), "image/png")
  end

  test "home page includes header registration call to action" do
    get root_path

    assert_response :success
    assert_select "a[href='#{new_participant_path}']", text: "Register now"
    assert_select "a[href='#{newsletter_path}']", text: "Newsletter"
    assert_select "a span.md\\:hidden", text: "EGC 2027"
    assert_select "a span.hidden.md\\:inline", text: "European Go Congress 2027"
    assert_select "p.hidden.md\\:block", text: "'s Hertogenbosch, the Netherlands, 24 Jul - 8 Aug, 2027"
    assert_select "a[aria-label='Discord'][href='https://discord.gg/m8cpSVbhMY']"
  end

  test "home page shows article main image in summaries when attached" do
    article = articles(:one)
    article.main_image.attach(image_upload)

    get root_path

    assert_response :success
    assert_select "img[alt=?]", "#{article.title} main image"
  end

  test "home page only shows active notices" do
    get root_path

    assert_response :success
    assert_select "p", text: notices(:one).title
    assert_select "p", text: notices(:one).body
    assert_select "p", text: notices(:two).title, count: 0
    assert_select "p", text: notices(:two).body, count: 0
  end
end
