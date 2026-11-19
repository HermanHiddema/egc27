import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["query", "value", "results", "status", "submit", "trigger", "panel", "selection"]
  static values = { url: String, autoSubmit: Boolean }

  connect() {
    if (this.hasSubmitTarget) this.submitTarget.disabled = !this.valueTarget.value
    this.activeIndex = -1
    this.unlockBasket()
  }

  disconnect() {
    clearTimeout(this.timer)
    this.request?.abort()
  }

  toggle() {
    if (this.panelTarget.classList.contains("hidden")) this.open()
    else this.close()
  }

  open() {
    this.panelTarget.classList.remove("hidden")
    this.triggerTarget.setAttribute("aria-expanded", "true")
    this.queryTarget.setAttribute("aria-expanded", "true")
    this.queryTarget.value = ""
    this.resultsTarget.replaceChildren()
    this.queryTarget.focus()
    this.load("")
  }

  openWithKeyboard(event) {
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      this.open()
    }
  }

  search() {
    clearTimeout(this.timer)
    this.request?.abort()
    this.statusTarget.textContent = ""
    this.resultsTarget.replaceChildren()
    this.activeIndex = -1
    this.queryTarget.removeAttribute("aria-activedescendant")
    const query = this.queryTarget.value.trim()
    this.timer = setTimeout(() => this.load(query), 200)
  }

  async load(query) {
    const request = new AbortController()
    this.request = request
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", query)
    try {
      const response = await fetch(url, { headers: { Accept: "application/json" }, signal: request.signal })
      if (!response.ok) throw new Error("Search failed")
      const matches = await response.json()
      if (request.signal.aborted || this.queryTarget.value.trim() !== query) return
      this.resultsTarget.replaceChildren()
      this.activeIndex = -1
      matches.forEach((match, index) => {
        const option = document.createElement("div")
        option.id = `${this.resultsTarget.id}_${index}`
        option.setAttribute("role", "option")
        option.setAttribute("aria-selected", "false")
        option.className = "cursor-pointer px-3 py-2 text-sm text-neutral-900 hover:bg-brand-blue-50"
        option.textContent = match.label
        option.addEventListener("mousedown", (event) => event.preventDefault())
        option.addEventListener("click", () => this.select(match))
        option.match = match
        this.resultsTarget.append(option)
      })
      this.statusTarget.textContent = matches.length ? `${matches.length} matches. Use the arrow keys to select.` : "No matches found."
    } catch (error) {
      if (error.name !== "AbortError") this.statusTarget.textContent = "Search could not be completed. Please try again."
    }
  }

  keydown(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.close()
      this.triggerTarget.focus()
      return
    }
    if (event.key === "Enter") event.preventDefault()
    const options = Array.from(this.resultsTarget.children)
    if (!options.length || this.panelTarget.classList.contains("hidden")) return
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      const step = event.key === "ArrowDown" ? 1 : -1
      this.activeIndex = this.activeIndex < 0 ? (step > 0 ? 0 : options.length - 1) : (this.activeIndex + step + options.length) % options.length
      options.forEach((option, index) => {
        const active = index === this.activeIndex
        option.classList.toggle("bg-brand-blue-50", active)
        option.setAttribute("aria-selected", String(active))
      })
      const active = options[this.activeIndex]
      this.queryTarget.setAttribute("aria-activedescendant", active.id)
      active.scrollIntoView({ block: "nearest" })
    } else if (event.key === "Enter") {
      event.preventDefault()
      if (this.activeIndex >= 0) this.select(options[this.activeIndex].match)
    }
  }

  select(match) {
    const changed = this.valueTarget.value !== String(match.id)
    this.selectionTarget.textContent = match.label
    this.valueTarget.value = match.id
    if (this.hasSubmitTarget) this.submitTarget.disabled = false
    this.statusTarget.textContent = ""
    this.close()
    if (this.autoSubmitValue && changed) {
      this.statusTarget.textContent = "Updating Order owner…"
      this.triggerTarget.disabled = true
      this.element.closest("[data-admin-basket]")?.querySelectorAll("[data-basket-content]").forEach((content) => content.setAttribute("inert", ""))
      this.element.requestSubmit()
    } else {
      this.triggerTarget.focus()
    }
  }

  blur(event) {
    if (!this.panelTarget.contains(event.relatedTarget) && event.relatedTarget !== this.triggerTarget) this.close()
  }

  close() {
    clearTimeout(this.timer)
    this.request?.abort()
    this.panelTarget.classList.add("hidden")
    this.triggerTarget.setAttribute("aria-expanded", "false")
    this.queryTarget.setAttribute("aria-expanded", "false")
    this.queryTarget.removeAttribute("aria-activedescendant")
  }

  submitted(event) {
    this.unlockBasket()
    if (this.autoSubmitValue && !event.detail.success) this.statusTarget.textContent = "Review the owner change or error message before continuing."
  }

  unlockBasket() {
    if (!this.autoSubmitValue) return
    this.triggerTarget.disabled = false
    this.element.closest("[data-admin-basket]")?.querySelectorAll("[data-basket-content]").forEach((content) => content.removeAttribute("inert"))
  }
}
