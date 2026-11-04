import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["dialog"]
    static values = { autoOpen: Boolean }

    connect() {
        if (this.autoOpenValue) this.open()
    }

    open() {
        if (this.dialogTarget.open) return

        this.dialogTarget.showModal()
        window.dispatchEvent(new Event("newsletter:subscribe-opened"))
        this.dialogTarget.querySelector("[autofocus]")?.focus()
    }

    close() {
        if (this.dialogTarget.open) this.dialogTarget.close()
    }

    closeOnBackdrop(event) {
        if (event.target === this.dialogTarget) this.close()
    }
}
