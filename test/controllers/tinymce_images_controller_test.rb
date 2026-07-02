require "test_helper"

class TinymceImagesControllerTest < ActionDispatch::IntegrationTest
  def image_upload
    Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/main-image.png"), "image/png")
  end

  test "editor can upload an image for tinymce" do
    sign_in users(:editor)

    post tinymce_images_path, params: { file: image_upload }, headers: { "Accept" => "application/json" }

    assert_response :created
    assert_match %r{/rails/active_storage/blobs/redirect/}, response.parsed_body["location"]
  end

  test "regular user cannot upload a tinymce image" do
    sign_in users(:one)

    post tinymce_images_path, params: { file: image_upload }, headers: { "Accept" => "application/json" }

    assert_response :forbidden
  end

  test "anonymous user cannot upload a tinymce image" do
    post tinymce_images_path, params: { file: image_upload }, headers: { "Accept" => "application/json" }

    assert_response :unauthorized
  end

  test "rejects unsupported image type" do
    sign_in users(:editor)

    post tinymce_images_path,
         params: {
           file: Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/main-image.svg"), "image/svg+xml")
         },
         headers: { "Accept" => "application/json" }

    assert_response :unprocessable_entity
  end
end
