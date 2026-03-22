import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["panel", "toggle"]

    connect() {
        this.close()
    }

    togglePanel() {
        if (this.panelTarget.classList.contains("hidden")) {
            this.open()
            return
        }

        this.close()
    }

    open() {
        this.panelTarget.classList.remove("hidden")
        this.toggleTarget.setAttribute("aria-expanded", "true")
    }

    close() {
        this.panelTarget.classList.add("hidden")
        this.toggleTarget.setAttribute("aria-expanded", "false")
    }
}
