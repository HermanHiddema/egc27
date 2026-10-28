import { Controller } from "@hotwired/stimulus"

// Calculates the price of a hostel booking while the form is filled in, listed
// as quantity × nights × price per item, summing to the total. The server
// recalculates the price when the booking is saved, so this is only a preview.
export default class extends Controller {
  static targets = ["arrival", "departure", "quantity", "breakfasts", "nights", "beds", "lines", "total"]
  static values = { prices: Object, beds: Object, labels: Object, breakfastCents: Number }

  connect() {
    this.calculate()
  }

  calculate() {
    const nights = this.nights()
    const lines = []
    let beds = 0

    this.quantityTargets.forEach((input) => {
      const roomType = input.dataset.roomType
      const quantity = this.count(input.value)
      beds += quantity * (this.bedsValue[roomType] || 0)
      if (quantity > 0) {
        lines.push({ label: this.labelsValue[roomType], quantity, unitCents: this.pricesValue[roomType] || 0 })
      }
    })

    const breakfasts = this.count(this.breakfastsTarget.value)
    if (breakfasts > 0) {
      lines.push({ label: this.labelsValue.breakfasts, quantity: breakfasts, unitCents: this.breakfastCentsValue })
    }
    this.breakfastsTarget.max = Math.min(beds, 99)

    const totalCents = lines.reduce((sum, line) => sum + line.quantity * nights * line.unitCents, 0)

    this.nightsTarget.textContent = nights
    this.bedsTarget.textContent = beds
    this.renderLines(lines, nights)
    this.totalTarget.textContent = this.formatEuros(totalCents)
  }

  renderLines(lines, nights) {
    if (lines.length === 0) {
      this.linesTarget.replaceChildren(this.row("Choose rooms or beds to see the price calculation.", null, "text-neutral-500"))
      return
    }

    const nightsLabel = `${nights} ${nights === 1 ? "night" : "nights"}`
    this.linesTarget.replaceChildren(...lines.map((line) => this.row(
      `${line.quantity} × ${line.label} × ${nightsLabel} × ${this.formatEuros(line.unitCents)}`,
      this.formatEuros(line.quantity * nights * line.unitCents),
      "min-[375px]:whitespace-nowrap text-neutral-900"
    )))
  }

  row(description, amount, className) {
    const tr = document.createElement("tr")
    const descriptionCell = document.createElement("td")
    descriptionCell.className = `py-2 pr-2 ${className}`
    descriptionCell.textContent = description
    tr.append(descriptionCell)

    if (amount !== null) {
      const amountCell = document.createElement("td")
      amountCell.className = "py-2 text-right whitespace-nowrap text-neutral-900"
      amountCell.textContent = amount
      tr.append(amountCell)
    }
    return tr
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
