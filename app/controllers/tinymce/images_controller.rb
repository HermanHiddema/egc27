class Tinymce::ImagesController < ApplicationController
  MAX_UPLOAD_BYTES = 10.megabytes
  ALLOWED_CONTENT_TYPES = %w[image/png image/jpeg image/gif image/webp].freeze

  skip_before_action :authenticate_user!
  before_action :authenticate_upload_user!
  before_action :require_upload_role!

  def create
    file = params[:file]

    unless file.respond_to?(:content_type)
      return render json: { error: "No file uploaded" }, status: :unprocessable_entity
    end

    unless ALLOWED_CONTENT_TYPES.include?(file.content_type.to_s)
      return render json: { error: "Unsupported image type" }, status: :unprocessable_entity
    end

    if file.size.to_i > MAX_UPLOAD_BYTES
      return render json: { error: "Image is too large (max 10MB)" }, status: :unprocessable_entity
    end

    blob = ActiveStorage::Blob.create_and_upload!(
      io: file.tempfile,
      filename: file.original_filename,
      content_type: file.content_type
    )

    render json: { location: url_for(blob) }, status: :created
  end

  private

  def authenticate_upload_user!
    return if current_user

    render json: { error: "Authentication required" }, status: :unauthorized
  end

  def require_upload_role!
    return if current_user&.can_create? || current_user&.can_edit?

    render json: { error: "You are not authorized to upload images." }, status: :forbidden
  end
end
