require "test_helper"

class ActiveStorageRoutesTest < ActionDispatch::IntegrationTest
  test "direct uploads endpoint is not routable" do
    post "/rails/active_storage/direct_uploads",
      params: { blob: { filename: "evil.html", byte_size: 4, checksum: "x", content_type: "text/html" } }
    assert_response :not_found

    assert_not Rails.application.routes.url_helpers.respond_to?(:rails_direct_uploads_path)
  end

  test "blob serving routes are still available" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("hello"),
      filename: "hello.txt",
      content_type: "text/plain"
    )

    path = Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true)
    assert_equal "/rails/active_storage/blobs/redirect/#{blob.signed_id}/hello.txt", path

    get path
    assert_response :redirect
  end
end
