import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["image", "removeField"]

  toggle() {
    const isRemoved = this.removeFieldTarget.value === "1"
    
    if (isRemoved) {
      // Restore the image
      this.removeFieldTarget.value = "0"
      this.imageTarget.classList.remove("opacity-40")
    } else {
      // Mark for removal
      this.removeFieldTarget.value = "1"
      this.imageTarget.classList.add("opacity-40")
    }
  }
}
