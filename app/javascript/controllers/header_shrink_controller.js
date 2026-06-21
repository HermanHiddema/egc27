import { Controller } from "@hotwired/stimulus"

// Matches Tailwind's `lg` breakpoint
const LG_BREAKPOINT = 1024
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
    this.isMobile = window.innerWidth < LG_BREAKPOINT
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
      this.isMobile = window.innerWidth < LG_BREAKPOINT
      this.onScroll()
    }, RESIZE_DEBOUNCE_MS)
  }

  onScroll() {
    const isShrunk = window.scrollY > this.thresholdValue

    if (this.isMobile) {
      this.navTarget.classList.toggle("h-64", !isShrunk)
      this.navTarget.classList.toggle("h-48", isShrunk)
      this.navTarget.classList.remove("lg:h-48", "lg:h-32")
    } else {
      this.navTarget.classList.toggle("lg:h-48", !isShrunk)
      this.navTarget.classList.toggle("lg:h-32", isShrunk)
      this.navTarget.classList.remove("h-64", "h-48")
    }

    this.logoTarget.classList.toggle("h-48", !isShrunk)
    this.logoTarget.classList.toggle("h-32", isShrunk)

    this.titleTarget.classList.toggle("text-4xl", !isShrunk)
    this.titleTarget.classList.toggle("text-3xl", isShrunk)

    if (this.menuOffsetElement) {
      if (this.isMobile) {
        this.menuOffsetElement.classList.toggle("top-64", !isShrunk)
        this.menuOffsetElement.classList.toggle("top-48", isShrunk)
        this.menuOffsetElement.classList.remove("lg:top-48", "lg:top-32")
      } else {
        this.menuOffsetElement.classList.toggle("lg:top-48", !isShrunk)
        this.menuOffsetElement.classList.toggle("lg:top-32", isShrunk)
        this.menuOffsetElement.classList.remove("top-64", "top-48")
      }
    }
  }
}
