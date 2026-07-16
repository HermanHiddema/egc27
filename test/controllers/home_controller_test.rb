require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  def image_upload
    Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/main-image.png"), "image/png")
  end

  test "home page includes header registration call to action" do
    get root_path

    assert_response :success
    assert_select "a[href='#{new_participant_path}'] span.hidden.lg\\:inline", text: "Register now"
    assert_select "a[href='#{newsletter_path}']", text: "Newsletter"
    assert_select "a span.md\\:hidden", text: "EGC 2027"
    assert_select "a span.hidden.md\\:inline", text: "European Go Congress"
    assert_select "p.hidden.md\\:block", text: "'s Hertogenbosch, the Netherlands, 24 July - 8 August, 2027"
    assert_select "a[aria-label='Discord'][href='https://discord.gg/m8cpSVbhMY']"
    assert_select "a[aria-label='WhatsApp'][href='https://chat.whatsapp.com/LPdN50HJlFaFvcaRVhmkPC']"
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
    assert_select "p[class~='text-[#5f4f00]']", text: notices(:one).title
    assert_select "p[class~='text-[#6f5f00]']", text: notices(:one).body
    assert_select "p[class~='text-[#5f4f00]']", text: notices(:two).title, count: 0
    assert_select "p[class~='text-[#6f5f00]']", text: notices(:two).body, count: 0
  end

  test "home page shows recently registered participants" do
    user = User.create!(email: "recent@example.org", skip_password_validation: true, confirmed_at: Time.current)

    11.times do |index|
      timestamp = 1.day.ago - index.minutes
      Participant.create!(
        first_name: "Extra#{index}",
        last_name: "Participant",
        email: "extra#{index}@example.org",
        age_group: "18-49",
        country: "NL",
        club: "Test Club",
        rank: 20,
        gender: "male",
        participant_type: "player",
        image_use_consent: true,
        accepted_terms_and_conditions: true,
        accepted_privacy_policy: true,
        confirmed_at: timestamp,
        user: user,
        created_at: timestamp,
        updated_at: timestamp
      )
    end

    get root_path

    assert_response :success
    assert_select "h2", text: "Recently Registered"
    assert_select "li span", text: "Alice Smith"
    assert_select "li span", text: "Bob Jones"
    assert_select "li span", text: participants(:one).rank_grade
    assert_select "li span", text: participants(:two).rank_grade
    assert_select "ul.divide-y.divide-gray-100 li", count: 10
  end

  test "home page shows sponsor carousel only for sponsors with a logo" do
    with_logo = sponsors(:one)
    with_logo.logo.attach(image_upload)

    get root_path

    assert_response :success
    assert_select "div[data-controller='sponsor-carousel']"
    assert_select "h2", text: "Our Sponsors"
    assert_select "a[href=?]", sponsors_path, text: "View all"
    assert_select "div[data-sponsor-carousel-target='slide']", count: 1
    assert_select "img[alt=?]", "#{with_logo.name} logo"
  end

  test "home page hides sponsor carousel when no sponsor has a logo" do
    get root_path

    assert_response :success
    assert_select "div[data-controller='sponsor-carousel']", count: 0
    assert_select "h2", text: "Our Sponsors", count: 0
  end
end
