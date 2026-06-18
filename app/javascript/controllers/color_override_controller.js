import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["enabled", "picker"]

  connect() {
    this.toggle()
  }

  toggle() {
    this.pickerTarget.disabled = !this.enabledTarget.checked
  }
}
