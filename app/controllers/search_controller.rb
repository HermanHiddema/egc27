class SearchController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]

  SEARCHABLE_TYPES = %w[Page Article Sponsor].freeze

  def index
    @query = params[:q].to_s.strip

    @results =
      if @query.present?
        PgSearch.multisearch(@query)
          .where(searchable_type: SEARCHABLE_TYPES)
          .includes(:searchable)
          .limit(50)
          .select { |document| readable_result?(document) }
      else
        []
      end
  end

  private

  # Pages that require a sign-in are hidden from search results for visitors.
  def readable_result?(document)
    return true unless document.searchable_type == "Page"

    document.searchable&.readable_by?(current_user)
  end
end
