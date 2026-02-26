import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]
  timeout = null

  closeOtherDropdowns() {
    const allMenus = document.querySelectorAll('[data-dropdown-target="menu"]')
    allMenus.forEach((menu) => {
      if (menu !== this.menuTarget) {
        menu.classList.add("hidden")
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
  }

  hide() {
    this.menuTarget.classList.add("hidden")
  }

  connect() {
    // Show on hover
    this.element.addEventListener("mouseenter", () => {
      if (this.timeout) {
        clearTimeout(this.timeout)
        this.timeout = null
      }
      this.closeOtherDropdowns()
      this.closeExternalSubmenus()
      this.show()
    })

    // Hide when mouse leaves the entire dropdown area with delay
    this.element.addEventListener("mouseleave", (e) => {
      // Check if we're leaving to a submenu
      const submenuIds = ['excursions-menu', 'meals-menu']
      const relatedTarget = e.relatedTarget

      if (relatedTarget) {
        const isGoingToSubmenu = submenuIds.some(id => {
          const submenu = document.getElementById(id)
          return submenu && (submenu === relatedTarget || submenu.contains(relatedTarget))
        })

        if (isGoingToSubmenu) {
          return // Don't hide if going to submenu
        }
      }

      this.timeout = setTimeout(() => {
        this.hide()
      }, 300)
    })

    // Also keep menu open if hovering over external submenus
    const submenuIds = ['excursions-menu', 'meals-menu']
    submenuIds.forEach(menuId => {
      const submenu = document.getElementById(menuId)
      if (submenu) {
        submenu.addEventListener('mouseenter', () => {
          if (this.timeout) {
            clearTimeout(this.timeout)
            this.timeout = null
          }
        })

        submenu.addEventListener('mouseleave', () => {
          this.timeout = setTimeout(() => {
            this.hide()
          }, 300)
        })
      }
    })
  }
}
