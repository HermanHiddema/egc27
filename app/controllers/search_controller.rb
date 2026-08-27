class SearchController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]

  SEARCHABLE_TYPES = %w[Page Article Sponsor].freeze

  def index
    @query = params[:q].to_s.strip

    @results =
      if @query.present?
        readable_documents
          .includes(:searchable)
          .limit(50)
      else
        []
      end
  end

  private

  # Pages that require a sign-in are excluded for visitors who are not signed in,
  # so that the result limit is applied to readable documents only.
  def readable_documents
    documents = PgSearch.multisearch(@query).where(searchable_type: SEARCHABLE_TYPES)
    return documents if current_user.present?

    restricted_pages = Page.where.not(access_level: :public).select(:id)
    return documents unless Page.where.not(access_level: :public).exists?

    documents.where.not(searchable_type: "Page", searchable_id: restricted_pages)
  end
end
