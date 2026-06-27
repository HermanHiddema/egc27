import { Controller } from "@hotwired/stimulus"

// Matches Tailwind's `lg` breakpoint
const LG_BREAKPOINT = 1024
const RESIZE_DEBOUNCE_MS = 100

function debounce(callback, waitMs) {
  let timeoutId = null

  const debounced = (...args) => {
    clearTimeout(timeoutId)
    timeoutId = setTimeout(() => callback(...args), waitMs)
  }

  debounced.cancel = () => {
    clearTimeout(timeoutId)
  }

  return debounced
}

function scheduleWithAnimationFrame(callback) {
  let frameId = null

  const scheduled = () => {
    if (frameId !== null) return

    frameId = requestAnimationFrame(() => {
      frameId = null
      callback()
    })
  }

  scheduled.cancel = () => {
    if (frameId !== null) {
      cancelAnimationFrame(frameId)
      frameId = null
    }
  }

  return scheduled
}

export default class extends Controller {
  static targets = ["nav", "logo", "title"]
  static values = {
    threshold: { type: Number, default: 24 },
    hysteresis: { type: Number, default: 16 },
    transitionLockMs: { type: Number, default: 340 }
  }

  connect() {
    this.menuOffsetElement = document.querySelector("[data-header-shrink-menu-offset]")
    this.onScroll = this.onScroll.bind(this)
    this.scheduledOnScroll = scheduleWithAnimationFrame(this.onScroll)
    this.onResize = this.onResize.bind(this)
    this.isMobile = window.innerWidth < LG_BREAKPOINT
    this.isShrunk = null
    this.lastScrollY = window.scrollY
    this.lockedUntil = 0
    this.resizeTimer = null
    window.addEventListener("scroll", this.scheduledOnScroll, { passive: true })
    window.addEventListener("resize", this.onResize, { passive: true })
    this.onScroll({ force: true })
  }

  disconnect() {
    window.removeEventListener("scroll", this.scheduledOnScroll)
    window.removeEventListener("resize", this.onResize)
    clearTimeout(this.resizeTimer)
    this.scheduledOnScroll.cancel()
  }

  onResize() {
    clearTimeout(this.resizeTimer)
    this.resizeTimer = setTimeout(() => {
      const wasMobile = this.isMobile
      this.isMobile = window.innerWidth < LG_BREAKPOINT
      this.onScroll({ force: wasMobile !== this.isMobile })
    }, RESIZE_DEBOUNCE_MS)
  }

  onScroll({ force = false } = {}) {
    const scrollY = window.scrollY
    const now = performance.now()

    if (!force && now < this.lockedUntil) {
      this.lastScrollY = scrollY
      return
    }

    const isScrollingUp = scrollY < this.lastScrollY
    this.lastScrollY = scrollY

    const isShrunk = this.nextShrinkState(scrollY, isScrollingUp)

    if (!force && this.isShrunk === isShrunk) return

    this.isShrunk = isShrunk
    this.lockedUntil = now + this.transitionLockMsValue

    this.applyShrinkState(isShrunk)
  }

  nextShrinkState(scrollY, isScrollingUp) {
    if (this.isShrunk === null) {
      return scrollY > this.thresholdValue
    }

    const shrinkAt = this.thresholdValue + this.hysteresisValue
    const expandAt = Math.max(0, this.thresholdValue - this.hysteresisValue)

    if (this.isShrunk) {
      return !(isScrollingUp && scrollY <= expandAt)
    }

    return scrollY > shrinkAt
  }

  applyShrinkState(isShrunk) {

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
