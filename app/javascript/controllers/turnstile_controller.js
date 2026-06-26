import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if (typeof window.turnstile !== "undefined") {
      this.renderWidget()
    } else {
      this._onTurnstileLoad = () => this.renderWidget()
      window.addEventListener("turnstile:load", this._onTurnstileLoad)
    }
  }

  disconnect() {
    if (this._onTurnstileLoad) {
      window.removeEventListener("turnstile:load", this._onTurnstileLoad)
      this._onTurnstileLoad = null
    }
  }

  renderWidget() {
    if (!this.element.querySelector("iframe")) {
      window.turnstile.render(this.element)
    }
  }
}
