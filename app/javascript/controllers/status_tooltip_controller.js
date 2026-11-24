import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "popup"]

  disconnect() {
    this.cancelClose()
  }

  showOnHover(event) {
    if (event.pointerType === "touch") return
    this.cancelClose()
    if (!this.popupTarget.matches(":popover-open")) {
      this.openedByHover = true
      this.open()
    }
  }

  toggle() {
    this.cancelClose()
    if (this.popupTarget.matches(":popover-open")) {
      if (this.openedByHover) {
        this.openedByHover = false
      } else {
        this.popupTarget.hidePopover()
      }
    } else {
      this.openedByHover = false
      this.open()
    }
  }

  open() {
    this.popupTarget.showPopover()
    const button = this.buttonTarget.getBoundingClientRect()
    const popup = this.popupTarget.getBoundingClientRect()
    const left = Math.max(8, Math.min(button.right - popup.width, window.innerWidth - popup.width - 8))
    const below = button.bottom + 8
    const top = below + popup.height <= window.innerHeight ? below : Math.max(8, button.top - popup.height - 8)
    Object.assign(this.popupTarget.style, { left: `${left}px`, top: `${top}px`, right: "auto", bottom: "auto" })
  }

  scheduleClose() {
    this.cancelClose()
    if (this.openedByHover) this.closeTimer = setTimeout(() => this.popupTarget.hidePopover(), 300)
  }

  cancelClose() {
    clearTimeout(this.closeTimer)
  }

  sync(event) {
    const open = event.newState === "open"
    this.buttonTarget.setAttribute("aria-expanded", String(open))
    if (!open) this.openedByHover = false
  }
}
