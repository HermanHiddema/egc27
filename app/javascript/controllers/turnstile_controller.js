import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Reinitialize Turnstile when this element is connected (on page load and after Turbo navigation)
    this.reinitializeTurnstile()
  }

  reinitializeTurnstile() {
    // Check if Turnstile is loaded
    if (typeof window.turnstile === "undefined") {
      return
    }

    // Find all Turnstile widgets on the page and reinitialize them
    const widgets = document.querySelectorAll(".cf-turnstile")
    widgets.forEach((widget) => {
      // Only render if not already rendered (checking for existing iframe)
      if (!widget.querySelector("iframe")) {
        window.turnstile.render(widget)
      }
    })
  }
}
