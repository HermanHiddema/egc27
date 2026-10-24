import { Controller } from "@hotwired/stimulus"

// Submits the associated form when an input fires the `submit` action,
// enabling filter controls (e.g. select menus) to apply without a button.
export default class extends Controller {
  static targets = ["name"]

  submitAfterDelay() {
    clearTimeout(this.submitTimeout)
    this.submitTimeout = setTimeout(() => this.submit(), 250)
  }

  preserveNameFocus() {
    if (!this.hasNameTarget || document.activeElement !== this.nameTarget) return

    sessionStorage.setItem("admin-participants-name-focus", JSON.stringify({
      value: this.nameTarget.value,
      start: this.nameTarget.selectionStart,
      end: this.nameTarget.selectionEnd
    }))
  }

  connect() {
    const saved = sessionStorage.getItem("admin-participants-name-focus")
    if (!saved || !this.hasNameTarget) return

    sessionStorage.removeItem("admin-participants-name-focus")
    try {
      const selection = JSON.parse(saved)
      if (selection.value !== this.nameTarget.value) return

      this.nameTarget.focus()
      this.nameTarget.setSelectionRange(selection.start, selection.end)
    } catch (_error) {
      // Ignore malformed stale state and leave the page in its normal focus state.
    }
  }

  submit() {
    if (typeof this.element.requestSubmit === "function") {
      this.element.requestSubmit()
    } else {
      this.element.submit()
    }
  }
}
