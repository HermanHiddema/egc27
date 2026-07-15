require "test_helper"

class SponsorsControllerTest < ActionDispatch::IntegrationTest
  def image_upload
    Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/main-image.png"), "image/png")
  end

  test "sponsors overview is publicly accessible without signing in" do
    get sponsors_path

    assert_response :success
    assert_select "h1", text: "Our Sponsors"
  end

  test "sponsors overview lists each sponsor with description and links" do
    sponsor = sponsors(:one)

    get sponsors_path

    assert_response :success
    assert_select "h2", text: sponsor.name
    assert_select "p", text: sponsor.description
    assert_select "a[href=?]", sponsor.website
    sponsor.social_media_links.each_value do |url|
      assert_select "a[href=?]", url
    end
  end

  test "sponsors overview alternates the logo side and renders attached logos" do
    sponsors(:one).logo.attach(image_upload)
    sponsors(:two).logo.attach(image_upload)

    get sponsors_path

    assert_response :success
    assert_select "img[alt=?]", "#{sponsors(:one).name} logo"
    assert_select "img[alt=?]", "#{sponsors(:two).name} logo"
    assert_select "div.sm\\:left-0"
    assert_select "div.sm\\:right-0"
  end

  test "sponsors overview hides admin controls from anonymous visitors" do
    get sponsors_path

    assert_response :success
    assert_select "a[href=?]", new_sponsor_path, count: 0
    assert_select "a[href=?]", edit_sponsor_path(sponsors(:one)), count: 0
  end

  test "sponsors overview shows admin controls to admins" do
    sign_in users(:admin)
    get sponsors_path

    assert_response :success
    assert_select "a[href=?]", new_sponsor_path, text: "New Sponsor"
    assert_select "a[href=?]", edit_sponsor_path(sponsors(:one)), text: "Edit"
  end
end
