import { Controller } from "@hotwired/stimulus"

const COUNTRY_NAME_OVERRIDES = {
    TW: "Chinese Taipei (Taiwan)"
}

const REGIONAL_INDICATOR_BASE = 127397

export default class extends Controller {
    static targets = ["select", "code"]

    connect() {
        this.displayNames = new Intl.DisplayNames(["en"], { type: "region" })
        this.enhanceSelect()
        this.enhanceCodes()
    }

    nameFor(code) {
        if (!code) return null
        return COUNTRY_NAME_OVERRIDES[code] || this.displayNames.of(code) || null
    }

    flagFor(code) {
        if (!code) return ""
        return [ ...code.toUpperCase() ].map((c) => String.fromCodePoint(REGIONAL_INDICATOR_BASE + c.charCodeAt(0))).join("")
    }

    enhanceSelect() {
        this.selectTargets.forEach((select) => {
            for (const option of select.options) {
                const code = option.value.trim().toUpperCase()
                if (!code) continue
                const name = this.nameFor(code)
                if (name) option.text = `${name} (${code})`
            }
        })
    }

    enhanceCodes() {
        this.codeTargets.forEach((el) => {
            const code = (el.dataset.countryCode || "").trim().toUpperCase()
            if (!code) return
            const name = this.nameFor(code)
            if (!name) return
            el.textContent = `${this.flagFor(code)} ${name}`.trim()
        })
    }
}
