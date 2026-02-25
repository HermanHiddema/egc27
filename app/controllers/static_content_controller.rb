class StaticContentController < ApplicationController
  skip_before_action :authenticate_user!

  # Static pages
  def sponsors; end
  def schedule; end
  def venue; end
  def contact; end

  # Go Tournaments
  def egc_rules; end
  def european_championship; end
  def main_open; end
  def weekend_tournament; end
  def pandanet; end
  def rapid; end
  def senior; end
  def youth; end
  def pair_go; end
  def marathon_9x9; end
  def marathon_13x13; end
  def blitz; end
  def women; end
  def teams; end
  def tsume_go; end
  def chess_and_go; end
  def beer_and_go; end
  def torus_go; end
  def hexgo; end

  # Other Activities
  def opening_ceremony; end
  def group_photo; end
  def egf_meeting; end
  def conference; end
  def prizegivings; end
  def game_reviews; end
  def simultaneous_games; end
  def lectures; end
  def tsume_go_activity; end
  def poker; end
  def other_games; end
  def sport; end
  def excursions_organised_local; end
  def excursions_organised_out_of_town; end
  def excursions_diy_local; end
  def excursions_diy_out_of_town; end

  # Eat and Drink
  def go_coins; end
  def vip_dinner; end
  def bbq_saturday; end
  def onsite_meals; end
  def local_restaurants; end
  def local_bars; end

  # Sleep
  def hotels; end
  def camping; end
  def budget_accommodation; end

  # Who is here
  def participants; end
  def teachers; end
  def shops; end
  def exhibitors; end
end
