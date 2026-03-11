import { Controller } from "@hotwired/stimulus"
import intlTelInput from "intl-tel-input"

export default class extends Controller {
    static targets = ["input"]

    static values = {
        countryFieldId: String
    }

    connect() {
        this.countryField = this.hasCountryFieldIdValue
            ? document.getElementById(this.countryFieldIdValue)
            : null

        const initialCountry = this.countryCode().toLowerCase()

        this.iti = intlTelInput(this.inputTarget, {
            initialCountry: initialCountry || "nl",
            nationalMode: false,
            autoPlaceholder: "aggressive",
            formatAsYouType: true,
            strictMode: false,
            loadUtils: () => import("intl-tel-input/utils")
        })

        this.syncCountryFieldFromSelected()
    }

    disconnect() {
        if (!this.iti) return
        this.iti.destroy()
        this.iti = null
    }

    format() {
        this.syncCountryFieldFromSelected()
    }

    normalize() {
        if (!this.iti) return

        const value = String(this.inputTarget.value || "").trim()
        if (value === "") return

        if (this.iti.isValidNumber()) {
            this.inputTarget.value = this.iti.getNumber()
        }

        this.syncCountryFieldFromSelected()
    }

    countryChanged() {
        this.syncCountryFieldFromSelected()
    }

    countryCode() {
        if (!this.countryField) return ""

        return String(this.countryField.value || "").trim().toUpperCase()
    }

    syncCountryFieldFromSelected() {
        if (!this.countryField || !this.iti) return

        const selected = this.iti.getSelectedCountryData()
        if (!selected || !selected.iso2) return

        this.countryField.value = String(selected.iso2).toUpperCase()
    }
}
