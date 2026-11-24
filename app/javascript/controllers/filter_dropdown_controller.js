import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  closeOutside(event) {
    if (!this.element.contains(event.target)) this.element.open = false
  }

  closeOnEscape(event) {
    if (event.key !== "Escape" || !this.element.open) return

    this.element.open = false
    this.element.querySelector("summary")?.focus()
  }
}
