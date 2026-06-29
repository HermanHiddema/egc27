import { Controller } from "@hotwired/stimulus"

// Initialises a TinyMCE editor on the controller's element (a textarea).
// TinyMCE itself is loaded as a local asset via a script tag that the layout
// only includes on pages that render the editor. Because that script loads
// asynchronously, we poll briefly for `window.tinymce` before init.
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

        const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content || ""

        window.tinymce.init({
            target: this.element,
            license_key: "gpl",
            menubar: false,
            plugins: this.pluginsValue,
            toolbar: this.toolbarValue,
            formats: {
                alignleft: { selector: "img,figure.image", classes: "img-align-left" },
                alignright: { selector: "img,figure.image", classes: "img-align-right" },
                aligncenter: { selector: "img,figure.image", classes: "img-align-center" },
                alignnone: { selector: "img,figure.image", classes: "img-align-none" }
            },
            image_class_list: [
                { title: "None", value: "" },
                { title: "Align left", value: "img-align-left" },
                { title: "Align right", value: "img-align-right" }
            ],
            content_style: `
                img.img-align-left, img.alignleft, figure.image.img-align-left, figure.image.image-style-align-left {
                    float: left;
                    margin: 0.25rem 1rem 0.75rem 0;
                }

                img.img-align-right, img.alignright, figure.image.img-align-right, figure.image.image-style-align-right {
                    float: right;
                    margin: 0.25rem 0 0.75rem 1rem;
                }

                figure.image {
                    max-width: 100%;
                }
            `,
            automatic_uploads: true,
            paste_data_images: true,
            images_upload_handler: (blobInfo) => new Promise((resolve, reject) => {
                const formData = new FormData()
                formData.append("file", blobInfo.blob(), blobInfo.filename())

                fetch("/tinymce/images", {
                    method: "POST",
                    credentials: "same-origin",
                    headers: {
                        "Accept": "application/json",
                        "X-CSRF-Token": csrfToken
                    },
                    body: formData
                })
                    .then(async (response) => {
                        if (!response.ok) {
                            const errorText = await response.text()
                            throw new Error(errorText || `Image upload failed (${response.status})`)
                        }

                        const json = await response.json()
                        if (!json.location) {
                            throw new Error("Image upload response did not include a location")
                        }

                        resolve(json.location)
                    })
                    .catch((error) => reject(error.message || "Image upload failed"))
            }),
            branding: false,
            promotion: false
        })
    }
}
