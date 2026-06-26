import { Controller } from "@hotwired/stimulus"

// Cycles through sponsor slides, showing one at a time.
// Auto-rotation is paused on hover or focus to meet WCAG 2.2.2.
export default class extends Controller {
  static targets = ["slide"]
  static values = { interval: { type: Number, default: 5000 } }

  connect() {
    this.index = 0
    this.showCurrent()

    if (this.slideTargets.length > 1 && !window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this._onPause = () => this.pause()
      this._onResume = () => this.resume()
      this._onFocusOut = (event) => {
        if (!this.element.contains(event.relatedTarget)) this.resume()
      }
      this.element.addEventListener("mouseenter", this._onPause)
      this.element.addEventListener("mouseleave", this._onResume)
      this.element.addEventListener("focusin", this._onPause)
      this.element.addEventListener("focusout", this._onFocusOut)
      this.startTimer()
    }
  }

  disconnect() {
    this.stopTimer()
    if (this._onPause) {
      this.element.removeEventListener("mouseenter", this._onPause)
      this.element.removeEventListener("mouseleave", this._onResume)
      this.element.removeEventListener("focusin", this._onPause)
      this.element.removeEventListener("focusout", this._onFocusOut)
    }
  }

  next() {
    this.index = (this.index + 1) % this.slideTargets.length
    this.showCurrent()
  }

  pause() {
    this.stopTimer()
  }

  resume() {
    if (!this.timer) this.startTimer()
  }

  startTimer() {
    this.timer = setInterval(() => this.next(), this.intervalValue)
  }

  stopTimer() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
  }

  showCurrent() {
    this.slideTargets.forEach((slide, index) => {
      slide.classList.toggle("hidden", index !== this.index)
    })
  }
}
