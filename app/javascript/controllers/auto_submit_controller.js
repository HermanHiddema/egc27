import { Controller } from "@hotwired/stimulus"

// Submits the associated form when an input fires the `submit` action,
// enabling filter controls (e.g. select menus) to apply without a button.
export default class extends Controller {
  submit() {
    if (typeof this.element.requestSubmit === "function") {
      this.element.requestSubmit()
    } else {
      this.element.submit()
    }
  }
}
