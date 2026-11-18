import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button", "picker", "timeButton", "timePicker"]
  static values = { datetime: Boolean }

  connect() {
    this.buttonTarget.hidden = typeof this.pickerTarget.showPicker !== "function"
    if (this.hasTimeButtonTarget) this.timeButtonTarget.hidden = typeof this.timePickerTarget.showPicker !== "function"
    this.syncPicker()
  }

  syncPicker() {
    const match = /^(\d{2})\/(\d{2})\/(\d{4})(?:\s|$)/.exec(this.inputTarget.value)
    this.pickerTarget.value = match ? `${match[3]}-${match[2]}-${match[1]}` : ""
    if (this.hasTimePickerTarget) this.timePickerTarget.value = this.inputTarget.value.match(/\s(\d{2}:\d{2})$/)?.[1] || ""
  }

  open() {
    this.syncPicker()
    this.pickerTarget.showPicker()
  }

  openTime() {
    this.syncPicker()
    this.timePickerTarget.showPicker()
  }

  pick() {
    const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(this.pickerTarget.value)
    if (!match) return

    const time = this.datetimeValue ? (this.inputTarget.value.match(/\s(\d{2}:\d{2})$/)?.[1] || "") : ""
    this.inputTarget.value = `${match[3]}/${match[2]}/${match[1]}${this.datetimeValue ? ` ${time}` : ""}`
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.inputTarget.focus()
  }

  pickTime() {
    if (!this.timePickerTarget.value) return

    const date = this.inputTarget.value.match(/^\S*/)?.[0] || ""
    this.inputTarget.value = `${date} ${this.timePickerTarget.value}`
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.inputTarget.focus()
    if (!/^\d{2}\/\d{2}\/\d{4}$/.test(date)) this.inputTarget.setSelectionRange(date.length, date.length)
  }
}
