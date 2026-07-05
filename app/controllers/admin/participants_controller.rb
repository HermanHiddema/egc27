class Admin::ParticipantsController < ApplicationController
  SORT_COLUMNS = %w[name email country club type rank rating status].freeze
  STATUS_FILTERS = %w[pending confirmed paid].freeze

  before_action :require_admin!
  before_action :set_participant, only: [:edit, :update]

  def index
    participants = Participant.includes(:payments)

    @countries = Participant.where.not(country: [nil, ""]).distinct.order(:country).pluck(:country)
    @country_filter = params[:country].to_s.upcase.presence
    @status_filter = STATUS_FILTERS.include?(params[:status]) ? params[:status] : nil
    @sort = permitted_sort
    @direction = permitted_direction

    participants = participants.where(country: @country_filter) if @country_filter.present?
    participants = filtered_by_status(participants, @status_filter) if @status_filter.present?

    @participants = sorted_participants(participants)
  end

  def edit
  end

  def update
    if @participant.update(participant_params)
      redirect_to admin_participants_path, notice: "Participant was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_participant
    @participant = Participant.find_by!(uuid: params[:id])
  end

  def permitted_sort
    SORT_COLUMNS.include?(params[:sort]) ? params[:sort] : "name"
  end

  def permitted_direction
    return params[:direction].to_sym if %w[asc desc].include?(params[:direction])

    # Default ordering (no explicit sort) is ascending; column clicks default to ascending too.
    :asc
  end

  # Restricts the list to participants whose derived registration_status matches
  # the requested filter, mirroring the Participant#registration_status logic:
  # Paid takes precedence over Confirmed, which takes precedence over Pending.
  def filtered_by_status(participants, status)
    paid_ids = Payment.completed.select(:participant_id)

    case status
    when "paid"
      participants.where(id: paid_ids)
    when "confirmed"
      participants.where.not(confirmed_at: nil).where.not(id: paid_ids)
    when "pending"
      participants.where(confirmed_at: nil).where.not(id: paid_ids)
    else
      participants
    end
  end

  def sorted_participants(participants)
    table = Participant.arel_table

    clauses =
      case @sort
      when "email"
        [ordered(nullif_blank(table[:email]))]
      when "country"
        [ordered(table[:country])]
      when "club"
        [ordered(nullif_blank(table[:club]))]
      when "type"
        [ordered(table[:participant_type])]
      when "rank"
        [ordered(table[:rank]), ordered(table[:rating])]
      when "rating"
        [ordered(table[:rating])]
      when "status"
        return status_sorted_participants(participants)
      else
        [ordered(table[:last_name]), ordered(table[:first_name])]
      end

    participants.order(*clauses, table[:last_name].asc, table[:first_name].asc, table[:id].asc)
  end

  # Registration status is derived, not a database column, so it is sorted in
  # Ruby after loading. Pending < Confirmed < Paid, reversed for descending.
  def status_sorted_participants(participants)
    order = { "Pending" => 0, "Confirmed" => 1, "Paid" => 2 }
    sorted = participants
      .sort_by { |participant| [order[participant.registration_status], participant.last_name.to_s.downcase, participant.first_name.to_s.downcase, participant.id] }

    @direction == :desc ? sorted.reverse : sorted
  end

  def ordered(column)
    ordering = @direction == :desc ? column.desc : column.asc
    ordering.nulls_last
  end

  def nullif_blank(column)
    Arel::Nodes::NamedFunction.new("NULLIF", [column, Arel::Nodes.build_quoted("")])
  end

  def participant_params
    params.require(:participant).permit(:first_name, :last_name, :email, :participant_type, :age_group, :country, :club, :rank, :rating, :egd_pin, :gender, :phone, :image_use_consent, :attendance_option)
  end
end
