import { Controller } from "@hotwired/stimulus"
import { COUNTRY_NAME_OVERRIDES } from "lib/country_names"

const ISO_COUNTRY_CODE_PATTERN = /^[A-Z]{2}$/

export default class extends Controller {
  static targets = ["select", "code"]

  connect() {
    this.displayNames = this.buildDisplayNames()
    if (!this.displayNames) return

    this.enhanceSelect()
    this.enhanceCodes()
  }

  buildDisplayNames() {
    if (typeof Intl === "undefined" || typeof Intl.DisplayNames !== "function") return null

    try {
      return new Intl.DisplayNames(["en"], { type: "region" })
    } catch {
      return null
    }
  }

  normalizeCode(code) {
    const normalizedCode = code?.trim()?.toUpperCase()
    return ISO_COUNTRY_CODE_PATTERN.test(normalizedCode) ? normalizedCode : null
  }

  nameFor(code) {
    const normalizedCode = this.normalizeCode(code)
    if (!normalizedCode || !this.displayNames) return null

    if (COUNTRY_NAME_OVERRIDES[normalizedCode]) return COUNTRY_NAME_OVERRIDES[normalizedCode]

    try {
      const name = this.displayNames.of(normalizedCode)
      if (!name || name === normalizedCode) return null
      return name
    } catch {
      return null
    }
  }

  enhanceSelect() {
    this.selectTargets.forEach((select) => {
      for (const option of select.options) {
        const code = this.normalizeCode(option.value)
        if (!code) continue

        const name = this.nameFor(code)
        if (name) option.text = `${name} (${code})`
      }
    })
  }

  enhanceCodes() {
    this.codeTargets.forEach((el) => {
      const code = this.normalizeCode(el.dataset.countryCode || "")
      if (!code) return

      const name = this.nameFor(code)
      if (!name) return

      const flagImage = el.querySelector("img")

      el.replaceChildren()
      if (flagImage) {
        el.append(flagImage)
        el.append(" ")
      }
      el.append(name)
    })
  }
}
