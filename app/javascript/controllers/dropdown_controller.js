import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "toggle"]
  timeout = null
  openedByHover = false

  closeOtherDropdowns() {
    const allDropdowns = document.querySelectorAll('[data-controller~="dropdown"]')

    allDropdowns.forEach((dropdown) => {
      if (dropdown !== this.element) {
        dropdown.querySelector('[data-dropdown-target="menu"]')?.classList.add("hidden")
        dropdown.querySelector('[data-dropdown-target="toggle"]')?.setAttribute("aria-expanded", "false")
        dropdown.querySelectorAll("[data-submenu-target]").forEach((submenu) => {
          submenu.classList.add("hidden")
          submenu.style.display = "none"
        })
      }
    })
  }

  // Returns all [data-submenu-target] elements that are DOM descendants of this dropdown.
  // These are sub-submenus that may be positioned outside the visual bounds of the dropdown
  // (e.g. via position:fixed) but still need to keep it open while hovered.
  submenus() {
    return Array.from(this.element.querySelectorAll("[data-submenu-target]"))
  }

  isInsideSubmenu(node) {
    return this.submenus().some((submenu) => submenu === node || submenu.contains(node))
  }

  show() {
    this.menuTarget.classList.remove("hidden")
    this.toggleTarget.setAttribute("aria-expanded", "true")
  }

  hide() {
    this.menuTarget.classList.add("hidden")
    this.toggleTarget.setAttribute("aria-expanded", "false")
    this.openedByHover = false
    this.submenus().forEach((submenu) => {
      submenu.classList.add("hidden")
      submenu.style.display = "none"
    })
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    if (this.menuTarget.classList.contains("hidden") || this.openedByHover) {
      if (this.timeout) {
        clearTimeout(this.timeout)
        this.timeout = null
      }

      this.closeOtherDropdowns()
      this.openedByHover = false
      this.show()
      return
    }

    this.hide()
  }

  connect() {
    this.hide()

    this.toggleClickHandler = (event) => this.toggle(event)
    this.documentClickHandler = (event) => {
      if (!this.element.contains(event.target)) {
        this.hide()
      }
    }
    this.focusOutHandler = (event) => {
      if (!this.element.contains(event.relatedTarget)) {
        this.hide()
      }
    }
    this.keydownHandler = (event) => {
      if (event.key === "Escape") {
        this.hide()
        this.toggleTarget.focus()
      }
    }

    this.toggleTarget.addEventListener("click", this.toggleClickHandler)
    document.addEventListener("click", this.documentClickHandler)
    this.element.addEventListener("focusout", this.focusOutHandler)
    this.element.addEventListener("keydown", this.keydownHandler)

    // Show on hover
    this.mouseEnterHandler = () => {
      if (this.timeout) {
        clearTimeout(this.timeout)
        this.timeout = null
      }
      this.closeOtherDropdowns()
      this.openedByHover = true
      this.show()
    }
    this.element.addEventListener("mouseenter", this.mouseEnterHandler)

    // Hide when mouse leaves the entire dropdown area with delay.
    // Skip if the pointer is moving into a sub-submenu that belongs to this dropdown.
    this.mouseLeaveHandler = (event) => {
      if (event.relatedTarget && this.isInsideSubmenu(event.relatedTarget)) {
        return
      }

      this.timeout = setTimeout(() => {
        this.openedByHover = false
        this.hide()
      }, 300)
    }
    this.element.addEventListener("mouseleave", this.mouseLeaveHandler)

    // Keep the dropdown open while hovering over any of its sub-submenus.
    this.submenuListeners = []
    this.submenus().forEach((submenu) => {
      const enterHandler = () => {
        if (this.timeout) {
          clearTimeout(this.timeout)
          this.timeout = null
        }
      }
      const leaveHandler = () => {
        this.timeout = setTimeout(() => {
          this.openedByHover = false
          this.hide()
        }, 300)
      }
      submenu.addEventListener("mouseenter", enterHandler)
      submenu.addEventListener("mouseleave", leaveHandler)
      this.submenuListeners.push({ submenu, enterHandler, leaveHandler })
    })
  }

  disconnect() {
    this.toggleTarget.removeEventListener("click", this.toggleClickHandler)
    document.removeEventListener("click", this.documentClickHandler)
    this.element.removeEventListener("focusout", this.focusOutHandler)
    this.element.removeEventListener("keydown", this.keydownHandler)
    this.element.removeEventListener("mouseenter", this.mouseEnterHandler)
    this.element.removeEventListener("mouseleave", this.mouseLeaveHandler)

    if (this.submenuListeners) {
      this.submenuListeners.forEach(({ submenu, enterHandler, leaveHandler }) => {
        submenu.removeEventListener("mouseenter", enterHandler)
        submenu.removeEventListener("mouseleave", leaveHandler)
      })
      this.submenuListeners = []
    }
  }
}
