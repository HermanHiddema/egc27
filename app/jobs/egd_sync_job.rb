# Refreshes the rank and rating of every participant that has a valid EGD pin
# from the European Go Database. Runs periodically (see config/recurring.yml)
# and can be triggered manually by admins from the participant list.
class EgdSyncJob < ApplicationJob
  queue_as :default

  def perform
    lookup = EgdLookupService.new
    updated = 0

    Participant.where.not(egd_pin: [nil, ""]).find_each do |participant|
      updated += 1 if sync(participant, lookup)
    end

    Rails.logger.info("EGD sync finished updated=#{updated}")
    updated
  end

  private

  def sync(participant, lookup)
    pin = participant.egd_pin.to_s.strip
    return false unless pin.match?(/\A\d{8}\z/)

    entry = lookup.search(query: pin).find { |row| row[:egd_pin].to_s == pin }
    return false if entry.blank?

    rank = entry[:playing_strength]
    rating = entry[:rating]
    return false if rank.blank? && rating.blank?

    participant.rank = rank if rank.present?
    participant.rating = rating if rating.present?
    return false unless participant.changed?

    unless participant.save
      Rails.logger.warn(
        "EGD sync failed for participant=#{participant.id} errors=#{participant.errors.full_messages.join(", ")}"
      )
      return false
    end

    true
  end
end
