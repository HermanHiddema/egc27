import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["panel", "recipients"]
    static values = { open: Boolean }

    connect() {
        if (this.openValue) this.open()
    }

    open() {
        this.panelTarget.hidden = false
        this.recipientsTarget.disabled = false
        this.recipientsTarget.focus()
    }

    close() {
        this.panelTarget.hidden = true
        this.recipientsTarget.disabled = true
    }
}
