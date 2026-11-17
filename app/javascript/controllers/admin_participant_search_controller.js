import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["query", "results", "status"]
  static values = { url: String }

  disconnect() {
    clearTimeout(this.timer)
    this.request?.abort()
  }

  search() {
    clearTimeout(this.timer)
    this.request?.abort()
    this.resultsTarget.replaceChildren(new Option("Type a name to search", ""))
    this.statusTarget.textContent = ""
    const query = this.queryTarget.value.trim()
    if (query.length < 2) return

    this.timer = setTimeout(() => this.load(query), 250)
  }

  async load(query) {
    this.request = new AbortController()
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", query)
    try {
      const response = await fetch(url, { headers: { Accept: "application/json" }, signal: this.request.signal })
      if (!response.ok) throw new Error("Search failed")
      const matches = await response.json()
      this.resultsTarget.replaceChildren(new Option(matches.length ? "Select a participant" : "No matches found", ""))
      matches.forEach((match) => this.resultsTarget.add(new Option(match.label, match.id)))
      this.statusTarget.textContent = matches.length ? `${matches.length} matching participants shown.` : "No participants found."
    } catch (error) {
      if (error.name !== "AbortError") this.statusTarget.textContent = "Search could not be completed. Please try again."
    }
  }
}
