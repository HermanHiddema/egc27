import { Controller } from "@hotwired/stimulus"

// Toggles a search field that expands from a magnifying-glass button in the
// header. The field is rendered as an absolutely positioned popover so opening
// it does not resize or squish the neighbouring call-to-action buttons.
export default class extends Controller {
  static targets = ["panel", "toggle", "input"]

  connect() {
    this.close()

    this.documentClickHandler = (event) => {
      if (!this.element.contains(event.target)) {
        this.close()
      }
    }
    this.keydownHandler = (event) => {
      if (event.key === "Escape") {
        this.close()
        this.toggleTarget.focus()
      }
    }
    this.focusOutHandler = (event) => {
      if (!this.element.contains(event.relatedTarget)) {
        this.close()
      }
    }

    document.addEventListener("click", this.documentClickHandler)
    this.element.addEventListener("keydown", this.keydownHandler)
    this.element.addEventListener("focusout", this.focusOutHandler)
  }

  disconnect() {
    document.removeEventListener("click", this.documentClickHandler)
    this.element.removeEventListener("keydown", this.keydownHandler)
    this.element.removeEventListener("focusout", this.focusOutHandler)
  }

  toggle(event) {
    event.preventDefault()

    if (this.panelTarget.classList.contains("hidden")) {
      this.open()
      return
    }

    this.close()
  }

  open() {
    this.panelTarget.classList.remove("hidden")
    this.toggleTarget.setAttribute("aria-expanded", "true")
    if (this.hasInputTarget) {
      this.inputTarget.focus()
    }
  }

  close() {
    this.panelTarget.classList.add("hidden")
    this.toggleTarget.setAttribute("aria-expanded", "false")
  }
}
