import { Controller } from "@hotwired/stimulus"

// Calculates the price of a hostel booking while the form is filled in. The
// server recalculates the price when the booking is saved, so this is only a
// preview for the user.
export default class extends Controller {
  static targets = ["arrival", "departure", "quantity", "breakfasts", "nights", "guests", "total"]
  static values = { prices: Object, guests: Object, breakfastCents: Number }

  connect() {
    this.calculate()
  }

  calculate() {
    const nights = this.nights()
    let guests = 0
    let perNightCents = 0

    this.quantityTargets.forEach((input) => {
      const roomType = input.dataset.roomType
      const quantity = this.count(input.value)
      guests += quantity * (this.guestsValue[roomType] || 0)
      perNightCents += quantity * (this.pricesValue[roomType] || 0)
    })

    perNightCents += this.count(this.breakfastsTarget.value) * this.breakfastCentsValue
    this.breakfastsTarget.max = guests

    this.nightsTarget.textContent = nights
    this.guestsTarget.textContent = guests
    this.totalTarget.textContent = this.formatEuros(perNightCents * nights)
  }

  nights() {
    const arrival = this.parseDate(this.arrivalTarget.value)
    const departure = this.parseDate(this.departureTarget.value)
    if (arrival === null || departure === null) return 0

    return Math.max(Math.round((departure - arrival) / 86400000), 0)
  }

  parseDate(value) {
    const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value || "")
    if (!match) return null

    return Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3]))
  }

  count(value) {
    const number = parseInt(value, 10)
    return Number.isFinite(number) && number > 0 ? number : 0
  }

  formatEuros(cents) {
    return `€ ${(cents / 100).toFixed(2)}`
  }
}
