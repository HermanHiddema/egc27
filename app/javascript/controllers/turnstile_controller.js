import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this._onNewsletterOpened = () => this.renderWidget()
    window.addEventListener("newsletter:subscribe-opened", this._onNewsletterOpened)

    if (typeof window.turnstile !== "undefined") {
      this.renderWidget()
    } else {
      this._onTurnstileLoad = () => this.renderWidget()
      window.addEventListener("turnstile:load", this._onTurnstileLoad)
    }
  }

  disconnect() {
    if (this._onNewsletterOpened) {
      window.removeEventListener("newsletter:subscribe-opened", this._onNewsletterOpened)
      this._onNewsletterOpened = null
    }

    if (this._onTurnstileLoad) {
      window.removeEventListener("turnstile:load", this._onTurnstileLoad)
      this._onTurnstileLoad = null
    }
  }

  renderWidget() {
    const dialog = this.element.closest("dialog")
    if (dialog && !dialog.open) return

    if (!this.element.querySelector("iframe")) {
      const widgetId = window.turnstile.render(this.element)
      this.element.dataset.turnstileWidgetId = String(widgetId)
    }
  }
}
