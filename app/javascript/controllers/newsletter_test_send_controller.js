import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["dialog", "recipients"]
    static values = { open: Boolean }

    connect() {
        if (this.openValue) this.open()
    }

    open() {
        if (this.dialogTarget.open) return
        if (!this.element.reportValidity()) return

        this.dialogTarget.showModal()
        this.recipientsTarget.disabled = false
        this.recipientsTarget.focus()
    }

    close() {
        if (this.dialogTarget.open) this.dialogTarget.close()
        this.recipientsTarget.disabled = true
    }

    closed() {
        this.recipientsTarget.disabled = true
    }

    closeOnBackdrop(event) {
        if (event.target === this.dialogTarget) this.close()
    }
}
