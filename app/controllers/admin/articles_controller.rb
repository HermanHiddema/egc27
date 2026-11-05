class Admin::ArticlesController < ApplicationController
  before_action :require_editor!

  def index
    @articles = Article.order(created_at: :desc)
  end
end
