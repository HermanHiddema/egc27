import { Controller } from "@hotwired/stimulus"

// Matches Tailwind's `sm` breakpoint
const SM_BREAKPOINT = 640
const RESIZE_DEBOUNCE_MS = 100

export default class extends Controller {
  static targets = ["nav", "logo", "title"]
  static values = {
    threshold: { type: Number, default: 24 }
  }

  connect() {
    this.menuOffsetElement = document.querySelector("[data-header-shrink-menu-offset]")
    this.onScroll = this.onScroll.bind(this)
    this.onResize = this.onResize.bind(this)
    this.isMobile = window.innerWidth < SM_BREAKPOINT
    this.resizeTimer = null
    window.addEventListener("scroll", this.onScroll, { passive: true })
    window.addEventListener("resize", this.onResize, { passive: true })
    this.onScroll()
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
    window.removeEventListener("resize", this.onResize)
    clearTimeout(this.resizeTimer)
  }

  onResize() {
    clearTimeout(this.resizeTimer)
    this.resizeTimer = setTimeout(() => {
      this.isMobile = window.innerWidth < SM_BREAKPOINT
      this.onScroll()
    }, RESIZE_DEBOUNCE_MS)
  }

  onScroll() {
    const isShrunk = window.scrollY > this.thresholdValue

    if (!this.isMobile) {
      this.navTarget.classList.toggle("h-24", !isShrunk)
      this.navTarget.classList.toggle("h-16", isShrunk)

      this.logoTarget.classList.toggle("h-24", !isShrunk)
      this.logoTarget.classList.toggle("h-16", isShrunk)
    }

    this.titleTarget.classList.toggle("text-4xl", !isShrunk)
    this.titleTarget.classList.toggle("text-3xl", isShrunk)

    if (this.menuOffsetElement) {
      const showTop24 = this.isMobile || !isShrunk
      this.menuOffsetElement.classList.toggle("top-24", showTop24)
      this.menuOffsetElement.classList.toggle("top-16", !showTop24)
    }
  }
}
