import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static values = { recipientCount: Number }

    confirm(event) {
        const submitter = event.submitter
        if (submitter?.name !== "intent" || submitter.value !== "send") return

        const count = this.recipientCountValue
        const addressees = count === 1 ? "addressee" : "addressees"
        const message = `Sending newsletter to ${count} ${addressees}. Are you sure?`

        if (!window.confirm(message)) {
            event.preventDefault()
            return
        }

        this.element.querySelector('[name="confirmed_send"]').value = "1"
    }
}
