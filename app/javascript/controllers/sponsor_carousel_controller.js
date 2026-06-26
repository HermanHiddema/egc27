import { Controller } from "@hotwired/stimulus"

// Cycles through sponsor slides, showing one at a time.
export default class extends Controller {
  static targets = ["slide"]
  static values = { interval: { type: Number, default: 5000 } }

  connect() {
    this.index = 0
    this.showCurrent()

    if (this.slideTargets.length > 1 && !window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.timer = setInterval(() => this.next(), this.intervalValue)
    }
  }

  disconnect() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
  }

  next() {
    this.index = (this.index + 1) % this.slideTargets.length
    this.showCurrent()
  }

  showCurrent() {
    this.slideTargets.forEach((slide, index) => {
      slide.classList.toggle("hidden", index !== this.index)
    })
  }
}
