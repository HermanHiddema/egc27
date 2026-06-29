import { Controller } from "@hotwired/stimulus"

// Initialises a TinyMCE editor on the controller's element (a textarea).
// TinyMCE itself is loaded from the Tiny Cloud CDN via a script tag that the
// layout only includes on pages that render the editor. Because that script
// loads asynchronously, we poll briefly for `window.tinymce` before init.
export default class extends Controller {
    static values = {
        plugins: { type: String, default: "lists link image table code autoresize" },
        toolbar: {
            type: String,
            default: "undo redo | blocks | bold italic underline | bullist numlist | link image | code"
        }
    }

    // Stop polling for the CDN script after roughly 10 seconds.
    static MAX_INIT_ATTEMPTS = 100

    connect() {
        this.initAttempts = 0
        this.initializeEditor()
    }

    disconnect() {
        if (this.pollTimeout) {
            clearTimeout(this.pollTimeout)
            this.pollTimeout = null
        }

        if (window.tinymce) {
            window.tinymce.remove(this.element)
        }
    }

    initializeEditor() {
        if (!window.tinymce) {
            this.initAttempts += 1
            if (this.initAttempts >= this.constructor.MAX_INIT_ATTEMPTS) {
                console.error("TinyMCE failed to load; falling back to a plain text area.")
                return
            }

            this.pollTimeout = setTimeout(() => this.initializeEditor(), 100)
            return
        }

        window.tinymce.init({
            target: this.element,
            menubar: false,
            plugins: this.pluginsValue,
            toolbar: this.toolbarValue,
            branding: false,
            promotion: false
        })
    }
}
