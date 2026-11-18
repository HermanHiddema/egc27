import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { message: String }

  confirm(event) {
    if (this.confirmed) {
      this.confirmed = false
      return
    }

    event.preventDefault()
    const dialog = document.getElementById("order-cancellation-dialog")
    if (!dialog || dialog.open) return

    const submitter = event.submitter
    dialog.querySelector("#order-cancellation-message").textContent = this.messageValue
    dialog.returnValue = ""
    dialog.addEventListener("close", () => {
      if (dialog.returnValue !== "confirm" || !this.element.isConnected) return

      this.confirmed = true
      if (submitter) this.element.requestSubmit(submitter)
      else this.element.requestSubmit()
    }, { once: true })
    dialog.showModal()
    dialog.querySelector("[autofocus]")?.focus()
  }
}
