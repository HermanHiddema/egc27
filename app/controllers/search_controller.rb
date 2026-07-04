class SearchController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]

  SEARCHABLE_TYPES = %w[Page Article Sponsor].freeze

  def index
    @query = params[:q].to_s.strip

    grouped =
      if @query.present?
        PgSearch.multisearch(@query)
          .where(searchable_type: SEARCHABLE_TYPES)
          .includes(:searchable)
          .group_by(&:searchable_type)
      else
        {}
      end

    @pages = records_for(grouped, "Page")
    @articles = records_for(grouped, "Article")
    @sponsors = records_for(grouped, "Sponsor")
  end

  private

  def records_for(grouped, type)
    Array(grouped[type]).filter_map(&:searchable)
  end
end
