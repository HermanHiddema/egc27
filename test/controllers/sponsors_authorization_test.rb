require "test_helper"

class SponsorsAuthorizationTest < ActionDispatch::IntegrationTest
  test "regular user cannot access new sponsor page" do
    sign_in users(:one)
    get new_sponsor_path
    assert_redirected_to root_path
  end

  test "editor cannot access new sponsor page" do
    sign_in users(:editor)
    get new_sponsor_path
    assert_redirected_to root_path
  end

  test "regular user cannot create sponsor" do
    sign_in users(:one)

    assert_no_difference "Sponsor.count" do
      post sponsors_path, params: { sponsor: { name: "Nope" } }
    end
    assert_redirected_to root_path
  end

  test "regular user cannot edit sponsor" do
    sign_in users(:one)
    get edit_sponsor_path(sponsors(:one))
    assert_redirected_to root_path
  end

  test "regular user cannot delete sponsor" do
    sign_in users(:one)

    assert_no_difference "Sponsor.count" do
      delete sponsor_path(sponsors(:one))
    end
    assert_redirected_to root_path
  end

  test "admin can access new sponsor page" do
    sign_in users(:admin)
    get new_sponsor_path
    assert_response :success
    assert_select "h1", text: "New Sponsor"
  end

  test "admin can create sponsor" do
    sign_in users(:admin)

    assert_difference "Sponsor.count", 1 do
      post sponsors_path, params: {
        sponsor: {
          name: "Created Sponsor",
          website: "https://created.example.org",
          description: "Created via test",
          social_media_links: { x: "https://x.com/created" }
        }
      }
    end

    assert_redirected_to sponsors_path
    sponsor = Sponsor.find_by!(name: "Created Sponsor")
    assert_equal "https://x.com/created", sponsor.social_media_links["x"]
  end

  test "admin can access edit sponsor page" do
    sign_in users(:admin)
    get edit_sponsor_path(sponsors(:one))
    assert_response :success
    assert_select "h1", text: "Edit Sponsor"
  end

  test "admin can update sponsor" do
    sign_in users(:admin)
    sponsor = sponsors(:one)

    patch sponsor_path(sponsor), params: {
      sponsor: {
        name: "Updated Sponsor Name",
        website: "https://updated.example.org",
        social_media_links: { x: "https://x.com/updated" }
      }
    }

    assert_redirected_to sponsors_path
    sponsor.reload
    assert_equal "Updated Sponsor Name", sponsor.name
    assert_equal "https://x.com/updated", sponsor.social_media_links["x"]
  end

  test "admin can delete sponsor" do
    sign_in users(:admin)

    assert_difference "Sponsor.count", -1 do
      delete sponsor_path(sponsors(:two))
    end

    assert_redirected_to sponsors_path
  end
end
