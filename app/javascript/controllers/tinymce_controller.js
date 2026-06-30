import { Controller } from "@hotwired/stimulus"

// Initialises a TinyMCE editor on the controller's element (a textarea).
// TinyMCE itself is loaded as a local asset via a script tag that the layout
// only includes on pages that render the editor. Because that script loads
// asynchronously, we poll briefly for `window.tinymce` before init.
export default class extends Controller {
    static values = {
        scriptUrl: String,
        plugins: { type: String, default: "lists link image table code autoresize quickbars" },
        toolbar: {
            type: String,
            default: "undo redo | blocks | bold italic underline | bullist numlist | link image table | code"
        }
    }

    // Stop polling for the CDN script after roughly 10 seconds.
    static MAX_INIT_ATTEMPTS = 100

    connect() {
        this.initAttempts = 0
        this.handleTurboRefresh = () => {
            this.initAttempts = 0
            this.initializeEditor()
        }
        this.handleTurboBeforeCache = () => {
            if (window.tinymce) {
                window.tinymce.remove(this.element)
            }
        }

        document.addEventListener("turbo:load", this.handleTurboRefresh)
        document.addEventListener("turbo:render", this.handleTurboRefresh)
        document.addEventListener("turbo:morph", this.handleTurboRefresh)
        document.addEventListener("turbo:before-cache", this.handleTurboBeforeCache)

        this.initializeEditor()
    }

    disconnect() {
        if (this.handleTurboRefresh) {
            document.removeEventListener("turbo:load", this.handleTurboRefresh)
            document.removeEventListener("turbo:render", this.handleTurboRefresh)
            document.removeEventListener("turbo:morph", this.handleTurboRefresh)
            this.handleTurboRefresh = null
        }

        if (this.handleTurboBeforeCache) {
            document.removeEventListener("turbo:before-cache", this.handleTurboBeforeCache)
            this.handleTurboBeforeCache = null
        }

        if (this.pollTimeout) {
            clearTimeout(this.pollTimeout)
            this.pollTimeout = null
        }

        if (window.tinymce) {
            window.tinymce.remove(this.element)
        }
    }

    get existingEditor() {
        if (!window.tinymce) return null

        if (this.element.id) {
            const byId = window.tinymce.get(this.element.id)
            if (byId) return byId
        }

        return (window.tinymce.editors || []).find((editor) => editor.targetElm === this.element) || null
    }

    static ensureTinymceLoaded(scriptUrl) {
        if (window.tinymce) {
            return Promise.resolve(window.tinymce)
        }

        this.loaderPromises ||= new Map()
        if (this.loaderPromises.has(scriptUrl)) {
            return this.loaderPromises.get(scriptUrl)
        }

        const loaderPromise = new Promise((resolve, reject) => {
            const existingScript = document.querySelector(`script[src="${scriptUrl}"]`)
            if (existingScript) {
                existingScript.addEventListener("load", () => resolve(window.tinymce), { once: true })
                existingScript.addEventListener("error", () => reject(new Error("Failed to load TinyMCE script")), { once: true })
                return
            }

            const script = document.createElement("script")
            script.src = scriptUrl
            script.async = true
            script.addEventListener("load", () => resolve(window.tinymce), { once: true })
            script.addEventListener("error", () => reject(new Error("Failed to load TinyMCE script")), { once: true })
            document.head.appendChild(script)
        })

        this.loaderPromises.set(scriptUrl, loaderPromise)
        return loaderPromise
    }

    initializeEditor() {
        if (!this.element.isConnected) {
            return
        }

        const existingEditor = this.existingEditor
        if (existingEditor) {
            const container = existingEditor.getContainer?.()
            if (container && container.isConnected) {
                return
            }

            existingEditor.remove()
        }

        if (!window.tinymce) {
            this.constructor.ensureTinymceLoaded(this.scriptUrlValue).catch(() => {
                // Fall through to polling and eventual graceful fallback.
            })

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
            block_formats: "Paragraph=p; Heading 2=h2; Heading 3=h3; Heading 4=h4",
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
            quickbars_image_toolbar: "alignleft aligncenter alignright | imageoptions",
            image_description: true,
            image_caption: true,
            table_toolbar: "tableprops tabledelete | tableinsertrowbefore tableinsertrowafter tabledeleterow | tableinsertcolbefore tableinsertcolafter tabledeletecol",
            table_default_attributes: {
                class: "tinymce-table"
            },
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

                figure.image figcaption {
                    text-align: center;
                }

                figure.image:has(> img.img-align-left),
                figure.image:has(> img.alignleft) {
                    float: left;
                    margin: 0.25rem 1rem 0.75rem 0;
                }

                figure.image:has(> img.img-align-right),
                figure.image:has(> img.alignright) {
                    float: right;
                    margin: 0.25rem 0 0.75rem 1rem;
                }

                figure.image:has(> img.img-align-center) {
                    float: none;
                    margin: 0.75rem auto;
                }

                figure.image:has(> img.img-align-none) {
                    float: none;
                    margin: 0.75rem 0;
                }

                table.tinymce-table {
                    width: 100%;
                    border-collapse: collapse;
                }

                table.tinymce-table th,
                table.tinymce-table td {
                    border: 1px solid #cbd5e1;
                    padding: 0.5rem;
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
