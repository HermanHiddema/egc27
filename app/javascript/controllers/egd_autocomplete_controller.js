import { Controller } from "@hotwired/stimulus"

const ISO_COUNTRY_CODES = [
    "AD", "AE", "AF", "AG", "AI", "AL", "AM", "AO", "AQ", "AR", "AS", "AT", "AU", "AW", "AX", "AZ",
    "BA", "BB", "BD", "BE", "BF", "BG", "BH", "BI", "BJ", "BL", "BM", "BN", "BO", "BQ", "BR", "BS",
    "BT", "BV", "BW", "BY", "BZ", "CA", "CC", "CD", "CF", "CG", "CH", "CI", "CK", "CL", "CM", "CN",
    "CO", "CR", "CU", "CV", "CW", "CX", "CY", "CZ", "DE", "DJ", "DK", "DM", "DO", "DZ", "EC", "EE",
    "EG", "EH", "ER", "ES", "ET", "FI", "FJ", "FK", "FM", "FO", "FR", "GA", "GB", "GD", "GE", "GF",
    "GG", "GH", "GI", "GL", "GM", "GN", "GP", "GQ", "GR", "GS", "GT", "GU", "GW", "GY", "HK", "HM",
    "HN", "HR", "HT", "HU", "ID", "IE", "IL", "IM", "IN", "IO", "IQ", "IR", "IS", "IT", "JE", "JM",
    "JO", "JP", "KE", "KG", "KH", "KI", "KM", "KN", "KP", "KR", "KW", "KY", "KZ", "LA", "LB", "LC",
    "LI", "LK", "LR", "LS", "LT", "LU", "LV", "LY", "MA", "MC", "MD", "ME", "MF", "MG", "MH", "MK",
    "ML", "MM", "MN", "MO", "MP", "MQ", "MR", "MS", "MT", "MU", "MV", "MW", "MX", "MY", "MZ", "NA",
    "NC", "NE", "NF", "NG", "NI", "NL", "NO", "NP", "NR", "NU", "NZ", "OM", "PA", "PE", "PF", "PG",
    "PH", "PK", "PL", "PM", "PN", "PR", "PS", "PT", "PW", "PY", "QA", "RE", "RO", "RS", "RU", "RW",
    "SA", "SB", "SC", "SD", "SE", "SG", "SH", "SI", "SJ", "SK", "SL", "SM", "SN", "SO", "SR", "SS",
    "ST", "SV", "SX", "SY", "SZ", "TC", "TD", "TF", "TG", "TH", "TJ", "TK", "TL", "TM", "TN", "TO",
    "TR", "TT", "TV", "TW", "TZ", "UA", "UG", "UM", "US", "UY", "UZ", "VA", "VC", "VE", "VG", "VI",
    "VN", "VU", "WF", "WS", "YE", "YT", "ZA", "ZM", "ZW"
]

const COUNTRY_NAME_OVERRIDES = {
    TW: "Chinese Taipei (Taiwan)"
}

export default class extends Controller {
    static targets = [
        "query",
        "results",
        "firstName",
        "lastName",
        "dateOfBirth",
        "countryInput",
        "countryCode",
        "countryDatalist",
        "club",
        "rank",
        "rating",
        "egdPin",
        "egdPinDisplay"
    ]

    static values = {
        url: String,
        pinUrl: String
    }

    connect() {
        this.matches = []
        this.searchTimeout = null
        this.countryByCode = new Map()
        this.codeByCountryName = new Map()
        this.initializeCountryAutocomplete()
    }

    search() {
        const query = this.queryTarget.value.trim()

        if (this.searchTimeout) {
            clearTimeout(this.searchTimeout)
        }

        if (query.length < 2) {
            this.hideResults()
            return
        }

        this.searchTimeout = setTimeout(() => this.performSearch(query), 250)
    }

    choose(event) {
        event.preventDefault()

        const index = Number(event.currentTarget.dataset.index)
        const match = this.matches[index]
        if (!match) return

        this.applyMatch(match)
    }

    applyMatch(match) {
        if (!match) return

        this.firstNameTarget.value = match.first_name || ""
        this.lastNameTarget.value = match.last_name || ""
        this.dateOfBirthTarget.value = this.formatDateForPicker(match.date_of_birth)
        this.applyCountryCode(match.country)
        this.clubTarget.value = match.club || ""
        this.rankTarget.value = match.playing_strength === null || match.playing_strength === undefined ? "" : String(match.playing_strength)
        this.ratingTarget.value = match.rating === null || match.rating === undefined ? "" : String(match.rating)
        this.egdPinTarget.value = match.egd_pin || ""
        if (this.hasEgdPinDisplayTarget) {
            this.egdPinDisplayTarget.value = match.egd_pin || ""
        }

        this.queryTarget.value = [match.first_name, match.last_name].filter(Boolean).join(" ")
        this.hideResults()
    }

    hide() {
        this.hideResults()
    }

    countryInputChanged() {
        this.syncCountryCodeFromInput(false)
    }

    countryInputBlur() {
        this.syncCountryCodeFromInput(true)
    }

    async performSearch(query) {
        try {
            const response = await fetch(this.buildUrl(query), {
                headers: {
                    Accept: "application/json"
                }
            })

            if (!response.ok) {
                this.hideResults()
                return
            }

            const payload = await response.json()
            this.matches = this.normalizePayload(payload)

            // A PIN is expected to map to a single player; auto-fill immediately.
            if (this.isPinQuery(query) && this.matches.length === 1) {
                this.applyMatch(this.matches[0])
                return
            }

            this.renderResults()
        } catch (_error) {
            this.hideResults()
        }
    }

    buildUrl(query) {
        const normalized = query.trim()

        if (this.isPinQuery(normalized)) {
            return this.buildPinUrl(normalized)
        }

        const url = new URL(this.urlValue)
        const parts = normalized.split(/\s+/).filter(Boolean)

        if (parts.length <= 1) {
            url.searchParams.set("lastname", this.withStartsWithPrefix(normalized))
            return url.toString()
        }

        const lastname = parts[parts.length - 1]
        const firstname = parts.slice(0, -1).join(" ")
        url.searchParams.set("lastname", this.withStartsWithPrefix(lastname))
        url.searchParams.set("name", firstname)
        return url.toString()
    }

    buildPinUrl(pin) {
        const baseUrl = this.hasPinUrlValue ? this.pinUrlValue : this.urlValue
        const url = new URL(baseUrl)
        url.searchParams.set("pin", pin)
        return url.toString()
    }

    isPinQuery(value) {
        return /^\d{8}$/.test(String(value || "").trim())
    }

    withStartsWithPrefix(value) {
        const normalized = String(value || "").trim()
        if (!normalized) return ""
        if (normalized.startsWith("@")) return normalized
        return `@${normalized}`
    }

    normalizePayload(payload) {
        if (Array.isArray(payload)) return payload

        if (payload && Array.isArray(payload.players)) {
            return payload.players.map((player) => this.mapEgdPlayer(player))
        }

        if (payload && typeof payload === "object") {
            if (this.payloadIsNoHit(payload)) {
                return []
            }

            return [this.mapEgdPlayer(payload)]
        }

        return []
    }

    payloadIsNoHit(payload) {
        if (!payload || typeof payload !== "object") return true

        const retcode = String(payload.retcode || payload.Retcode || "").trim().toLowerCase()
        const hasPlayerFields = ["Name", "Last_Name", "Real_Name", "Real_Last_Name", "Pin_Player", "Country_Code", "Club", "Grade_n", "Gor"]
            .some((key) => Object.prototype.hasOwnProperty.call(payload, key))

        // Some successful EGD payloads include retcode alongside player data.
        if (hasPlayerFields) return false

        if (!retcode) return false

        return ["notfound", "not_found", "noresult", "no_result", "error", "failed", "ko"].includes(retcode)
    }

    initializeCountryAutocomplete() {
        if (!this.hasCountryInputTarget || !this.hasCountryCodeTarget || !this.hasCountryDatalistTarget) return

        const codes = this.isoCountryCodes()
        const displayNames = new Intl.DisplayNames(["en"], { type: "region" })

        const countries = codes
            .map((code) => {
                const name = COUNTRY_NAME_OVERRIDES[code] || displayNames.of(code)
                return { code, name: name || code }
            })
            .sort((a, b) => a.name.localeCompare(b.name))

        this.countryByCode.clear()
        this.codeByCountryName.clear()

        const options = countries.map(({ code, name }) => {
            this.countryByCode.set(code, name)
            this.codeByCountryName.set(name.toLowerCase(), code)
            return `<option value="${this.escapeHtml(name)} (${code})"></option>`
        })

        this.countryDatalistTarget.innerHTML = options.join("")

        if (this.countryCodeTarget.value) {
            this.applyCountryCode(this.countryCodeTarget.value)
        }
    }

    isoCountryCodes() {
        return ISO_COUNTRY_CODES
    }

    applyCountryCode(value) {
        const code = String(value || "").trim().toUpperCase()
        if (!code) {
            this.countryCodeTarget.value = ""
            this.countryInputTarget.value = ""
            return
        }

        const name = this.countryByCode.get(code)
        if (!name) {
            this.countryCodeTarget.value = ""
            this.countryInputTarget.value = ""
            return
        }

        this.countryCodeTarget.value = code
        this.countryInputTarget.value = `${name} (${code})`
    }

    syncCountryCodeFromInput(normalizeDisplay) {
        const inputValue = String(this.countryInputTarget.value || "").trim()
        if (!inputValue) {
            this.countryCodeTarget.value = ""
            return
        }

        const codeMatch = inputValue.match(/^([A-Za-z]{2})$/)
        if (codeMatch) {
            const code = codeMatch[1].toUpperCase()
            if (this.countryByCode.has(code)) {
                this.countryCodeTarget.value = code
                if (normalizeDisplay) {
                    this.applyCountryCode(code)
                }
            } else {
                this.countryCodeTarget.value = ""
                if (normalizeDisplay) {
                    this.countryInputTarget.value = ""
                }
            }
            return
        }

        const suffixMatch = inputValue.match(/\(([A-Za-z]{2})\)\s*$/)
        if (suffixMatch) {
            this.applyCountryCode(suffixMatch[1])
            return
        }

        const byName = this.codeByCountryName.get(inputValue.toLowerCase())
        if (byName) {
            this.countryCodeTarget.value = byName
            if (normalizeDisplay) {
                this.applyCountryCode(byName)
            }
            return
        }

        this.countryCodeTarget.value = ""
        if (normalizeDisplay) {
            this.countryInputTarget.value = ""
        }
    }

    mapEgdPlayer(player) {
        const playingStrength = this.toInteger(player.Grade_n)
        return {
            first_name: this.normalizeSpaces(player.Name || player.Real_Name || ""),
            last_name: this.normalizeSpaces(player.Last_Name || player.Real_Last_Name || ""),
            date_of_birth: "",
            country: this.normalizeSpaces(player.Country_Code || ""),
            club: this.normalizeSpaces(player.Club || ""),
            playing_strength: playingStrength,
            playing_strength_label: this.normalizeSpaces(player.Grade || this.gradeLabel(playingStrength)),
            rating: this.toInteger(player.Gor),
            egd_pin: this.normalizeSpaces(player.Pin_Player || "")
        }
    }

    toInteger(value) {
        if (value === null || value === undefined) return null

        const text = String(value).trim()
        if (text === "") return null

        const parsed = Number(value)
        if (Number.isNaN(parsed)) return null
        return Math.trunc(parsed)
    }

    renderResults() {
        if (!Array.isArray(this.matches) || this.matches.length === 0) {
            this.hideResults()
            return
        }

        const items = this.matches.map((match, index) => {
            const name = [match.first_name, match.last_name].filter(Boolean).join(" ")
            const details = [
                match.country,
                match.playing_strength_label || this.gradeLabel(match.playing_strength),
                match.rating === null || match.rating === undefined ? "" : `GOR ${match.rating}`,
                match.egd_pin
            ].filter(Boolean).join(" • ")

            return `
        <button
          type="button"
          data-index="${index}"
          data-action="mousedown->egd-autocomplete#choose"
          class="block w-full text-left px-3 py-2 hover:bg-neutral-100 transition-colors"
        >
          <div class="font-medium text-neutral-900">${this.escapeHtml(name)}</div>
          <div class="text-xs text-neutral-600">${this.escapeHtml(details)}</div>
        </button>
      `
        })

        this.resultsTarget.innerHTML = items.join("")
        this.resultsTarget.classList.remove("hidden")
    }

    hideResults() {
        this.resultsTarget.innerHTML = ""
        this.resultsTarget.classList.add("hidden")
    }

    gradeLabel(gradeN) {
        if (gradeN === null || gradeN === undefined || String(gradeN).trim() === "") return ""

        const parsed = Number(gradeN)
        if (Number.isNaN(parsed) || parsed < 0 || parsed > 47) return ""
        if (parsed <= 29) return `${30 - parsed} kyu`
        if (parsed <= 38) return `${parsed - 29} dan`
        return `${parsed - 38} dan pro`
    }

    normalizeSpaces(value) {
        return String(value || "").replaceAll("_", " ")
    }

    escapeHtml(value) {
        return String(value || "")
            .replaceAll("&", "&amp;")
            .replaceAll("<", "&lt;")
            .replaceAll(">", "&gt;")
            .replaceAll('"', "&quot;")
            .replaceAll("'", "&#39;")
    }

    formatDateForPicker(value) {
        const raw = String(value || "").trim()
        if (!raw) return ""

        if (/^\d{4}-\d{2}-\d{2}$/.test(raw)) return raw

        const euMatch = raw.match(/^(\d{2})-(\d{2})-(\d{4})$/)
        if (euMatch) {
            return `${euMatch[3]}-${euMatch[2]}-${euMatch[1]}`
        }

        return raw
    }
}
