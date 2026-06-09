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
      }
    })
  }

  closeExternalSubmenus() {
    const externalSubmenuIds = ["excursions-menu", "meals-menu"]
    externalSubmenuIds.forEach((id) => {
      const submenu = document.getElementById(id)
      if (submenu) {
        submenu.style.display = "none"
        submenu.classList.add("hidden")
      }
    })
  }

  show() {
    this.menuTarget.classList.remove("hidden")
    this.toggleTarget.setAttribute("aria-expanded", "true")
  }

  hide() {
    this.menuTarget.classList.add("hidden")
    this.toggleTarget.setAttribute("aria-expanded", "false")
    this.openedByHover = false
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
      this.closeExternalSubmenus()
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
      this.closeExternalSubmenus()
      this.openedByHover = true
      this.show()
    }
    this.element.addEventListener("mouseenter", this.mouseEnterHandler)

    // Hide when mouse leaves the entire dropdown area with delay
    this.mouseLeaveHandler = (event) => {
      // Check if we're leaving to a submenu
      const submenuIds = ["excursions-menu", "meals-menu"]
      const relatedTarget = event.relatedTarget

      if (relatedTarget) {
        const isGoingToSubmenu = submenuIds.some((id) => {
          const submenu = document.getElementById(id)
          return submenu && (submenu === relatedTarget || submenu.contains(relatedTarget))
        })

        if (isGoingToSubmenu) {
          return // Don't hide if going to submenu
        }
      }

      this.timeout = setTimeout(() => {
        this.openedByHover = false
        this.hide()
      }, 300)
    }
    this.element.addEventListener("mouseleave", this.mouseLeaveHandler)

    // Also keep menu open if hovering over external submenus
    this.externalSubmenuListeners = []
    const submenuIds = ["excursions-menu", "meals-menu"]
    submenuIds.forEach((menuId) => {
      const submenu = document.getElementById(menuId)
      if (submenu) {
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
        this.externalSubmenuListeners.push({ submenu, enterHandler, leaveHandler })
      }
    })
  }

  disconnect() {
    this.toggleTarget.removeEventListener("click", this.toggleClickHandler)
    document.removeEventListener("click", this.documentClickHandler)
    this.element.removeEventListener("focusout", this.focusOutHandler)
    this.element.removeEventListener("keydown", this.keydownHandler)
    this.element.removeEventListener("mouseenter", this.mouseEnterHandler)
    this.element.removeEventListener("mouseleave", this.mouseLeaveHandler)

    if (this.externalSubmenuListeners) {
      this.externalSubmenuListeners.forEach(({ submenu, enterHandler, leaveHandler }) => {
        submenu.removeEventListener("mouseenter", enterHandler)
        submenu.removeEventListener("mouseleave", leaveHandler)
      })
      this.externalSubmenuListeners = []
    }
  }
}
