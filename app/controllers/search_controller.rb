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
      else
        []
      end
  end
end
