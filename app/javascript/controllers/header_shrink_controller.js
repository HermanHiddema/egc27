import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["nav", "logo", "title"]
  static values = {
    threshold: { type: Number, default: 24 }
  }

  connect() {
    this.menuOffsetElement = document.querySelector("[data-header-shrink-menu-offset]")
    this.onScroll = this.onScroll.bind(this)
    window.addEventListener("scroll", this.onScroll, { passive: true })
    this.onScroll()
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
  }

  onScroll() {
    const isShrunk = window.scrollY > this.thresholdValue

    this.navTarget.classList.toggle("h-24", !isShrunk)
    this.navTarget.classList.toggle("h-16", isShrunk)

    this.logoTarget.classList.toggle("h-24", !isShrunk)
    this.logoTarget.classList.toggle("h-16", isShrunk)

    this.titleTarget.classList.toggle("text-4xl", !isShrunk)
    this.titleTarget.classList.toggle("text-3xl", isShrunk)

    if (this.menuOffsetElement) {
      this.menuOffsetElement.classList.toggle("top-24", !isShrunk)
      this.menuOffsetElement.classList.toggle("top-16", isShrunk)
    }
  }
}
