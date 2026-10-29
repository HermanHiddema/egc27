import { Controller } from "@hotwired/stimulus"

// Initialises a TinyMCE editor on the controller's element (a textarea).
// TinyMCE itself is loaded as a local asset via a script tag that the layout
// only includes on pages that render the editor. Because that script loads
// asynchronously, we poll briefly for `window.tinymce` before init.
export default class extends Controller {
    static values = {
        scriptUrl: String,
        newsletterLayouts: { type: Boolean, default: false },
        newsletterPlaceholderImage: String,
        plugins: { type: String, default: "lists link image table code autoresize quickbars" },
        toolbar: {
            type: String,
            default: "undo redo | blocks | bold italic underline | bullist numlist | link image table | code"
        }
    }

    // Stop polling for the CDN script after roughly 10 seconds.
    static MAX_INIT_ATTEMPTS = 100
    static TEXT_ALIGN_SELECTOR = "p,h1,h2,h3,h4,h5,h6,blockquote,pre,li"
    static IMAGE_ALIGNMENTS = {
        JustifyLeft: { className: "img-align-left", styles: { float: "left", margin: "0.25rem 1rem 0.75rem 0" } },
        JustifyRight: { className: "img-align-right", styles: { float: "right", margin: "0.25rem 0 0.75rem 1rem" } },
        JustifyCenter: { className: "img-align-center", styles: { float: "none", margin: "0.75rem auto" } },
        JustifyNone: { className: "img-align-none", styles: { float: "none", margin: "0.75rem 0" } }
    }

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

        const config = {
            target: this.element,
            license_key: "gpl",
            menubar: false,
            plugins: this.pluginsValue,
            toolbar: this.toolbarValue,
            toolbar_mode: this.newsletterLayoutsValue ? "wrap" : undefined,
            contextmenu: this.newsletterLayoutsValue ? false : undefined,
            quickbars_insert_toolbar: this.newsletterLayoutsValue ? false : undefined,
            object_resizing: this.newsletterLayoutsValue ? "img" : true,
            block_formats: "Paragraph=p; Heading 2=h2; Heading 3=h3; Heading 4=h4",
            formats: {
                alignleft: { selector: this.constructor.TEXT_ALIGN_SELECTOR, styles: { "text-align": "left" }, inherit: false },
                alignright: { selector: this.constructor.TEXT_ALIGN_SELECTOR, styles: { "text-align": "right" }, inherit: false },
                aligncenter: { selector: this.constructor.TEXT_ALIGN_SELECTOR, styles: { "text-align": "center" }, inherit: false },
                alignnone: { selector: this.constructor.TEXT_ALIGN_SELECTOR, styles: { "text-align": "left" }, inherit: false }
            },
            image_class_list: [
                { title: "None", value: "" },
                { title: "Align left", value: "img-align-left" },
                { title: "Align right", value: "img-align-right" }
            ],
            quickbars_image_toolbar: "alignleft aligncenter alignright | imageoptions",
            image_description: true,
            image_caption: true,
            table_toolbar: this.newsletterLayoutsValue ? "" : "tableprops tabledelete | tableinsertrowbefore tableinsertrowafter tabledeleterow | tableinsertcolbefore tableinsertcolafter tabledeletecol",
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

                img.img-align-center {
                    float: none;
                    margin: 0.75rem auto;
                }

                img.img-align-none {
                    float: none;
                    margin: 0.75rem 0;
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

                table.newsletter-layout-locked {
                    width: 100%;
                    table-layout: fixed;
                    border-collapse: collapse;
                    height: auto !important;
                }

                table.newsletter-layout-locked tr,
                table.newsletter-layout-locked td {
                    border: 1px dashed #cbd5e1;
                    padding: 0.5rem;
                    vertical-align: top;
                    height: auto !important;
                }

                .newsletter-layout-editable img {
                    display: block;
                    max-width: 100%;
                    height: auto;
                }

                .newsletter-layout-editable figure.image {
                    display: block;
                    width: 100%;
                    max-width: 100%;
                    margin: 0;
                }

                .newsletter-layout-editable figure.image img {
                    margin: 0;
                }
            `,
            convert_urls: false,
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
        }

        config.setup = (editor) => {
            this.registerImageAlignment(editor)
            if (this.newsletterLayoutsValue) this.registerNewsletterLayoutButtons(editor)
        }

        window.tinymce.init(config)
    }

    registerImageAlignment(editor) {
        const alignments = this.constructor.IMAGE_ALIGNMENTS
        const alignmentClasses = Object.values(alignments).map(({ className }) => className)

        editor.on("BeforeExecCommand", (event) => {
            const alignment = alignments[event.command]
            if (!alignment) return

            const node = editor.selection.getNode()
            const image = editor.dom.getParent(node, "figure.image") || (node?.nodeName === "IMG" ? node : null)
            if (!image) return

            event.preventDefault()
            editor.undoManager.transact(() => {
                alignmentClasses.forEach((className) => editor.dom.removeClass(image, className))
                editor.dom.addClass(image, alignment.className)
                editor.dom.setStyles(image, alignment.styles)
            })
            editor.nodeChanged()
        })
    }

    registerNewsletterLayoutButtons(editor) {
        const imageUrl = this.newsletterPlaceholderImageValue
        const textCell = '<div class="newsletter-layout-editable" contenteditable="true"><p>Write your text here.</p></div>'
        const imageCell = `<div class="newsletter-layout-editable" contenteditable="true"><img class="newsletter-layout-image" src="${imageUrl}" alt="Replace this sample image with your own" width="552" style="display:block; max-width:100%;"></div>`

        const layoutTable = (leftContent, rightContent) => `
            <table class="newsletter-layout-locked" contenteditable="false" width="100%" cellpadding="0" cellspacing="0" border="0" style="width:100%; border-collapse:collapse; margin:16px 0;">
                <tbody><tr>
                    <td class="newsletter-layout-column" width="50%" valign="top" style="width:50%; padding:8px; vertical-align:top;">${leftContent}</td>
                    <td class="newsletter-layout-column" width="50%" valign="top" style="width:50%; padding:8px; vertical-align:top;">${rightContent}</td>
                </tr></tbody>
            </table><p></p>`

        const fullTextBlock = `
            <table class="newsletter-layout-locked" contenteditable="false" width="100%" cellpadding="0" cellspacing="0" border="0" style="width:100%; border-collapse:collapse; margin:16px 0;">
                <tbody><tr><td class="newsletter-layout-column" width="100%" valign="top" style="width:100%; padding:8px; vertical-align:top;">
                    ${textCell}
                </td></tr></tbody>
            </table><p></p>`

        const layouts = [
            ["newsletter_full_text", "Full-width text", null, null],
            ["newsletter_text_image", "Text + image", textCell, imageCell],
            ["newsletter_image_text", "Image + text", imageCell, textCell],
            ["newsletter_image_image", "Image + image", imageCell, imageCell]
        ]

        const newsletterImageSources = new WeakMap()
        const normalizeLayoutTableHeights = () => {
            editor.dom.select(".newsletter-layout-locked, .newsletter-layout-locked tr, .newsletter-layout-locked td").forEach((element) => {
                element.removeAttribute("height")
                element.style.removeProperty("height")
            })
        }
        const sizeNewLayoutImage = (image) => {
            const source = image.getAttribute("src")
            if (!source || newsletterImageSources.get(image) === source) return

            newsletterImageSources.set(image, source)
            const sourceWidth = image.naturalWidth || Number(image.getAttribute("width"))
            const sourceHeight = image.naturalHeight || Number(image.getAttribute("height"))

            if (!sourceWidth || !sourceHeight) {
                newsletterImageSources.delete(image)
                image.addEventListener("load", () => sizeNewLayoutImage(image), { once: true })
                return
            }

            const cell = image.closest("td")
            const view = image.ownerDocument.defaultView
            const cellStyle = cell && view ? view.getComputedStyle(cell) : null
            const padding = cellStyle ? parseFloat(cellStyle.paddingLeft) + parseFloat(cellStyle.paddingRight) : 0
            const cellWidth = cell ? Math.round(cell.getBoundingClientRect().width - padding) : 0
            const fittedWidth = Math.max(1, Math.min(sourceWidth, cellWidth || 552))
            const fittedHeight = Math.max(1, Math.round(sourceHeight * fittedWidth / sourceWidth))

            image.classList.add("newsletter-layout-image")
            image.removeAttribute("height")
            image.style.removeProperty("width")
            image.style.removeProperty("height")
            editor.dom.setStyles(image, { display: "block", maxWidth: "100%" })
            image.setAttribute("width", String(fittedWidth))
            image.setAttribute("height", String(fittedHeight))

            const figure = image.closest("figure.image")
            if (figure) {
                editor.dom.setStyles(figure, { display: "block", width: "100%", maxWidth: "100%", margin: "0" })
            }
        }

        editor.on("init", normalizeLayoutTableHeights)
        editor.on("init", () => {
            editor.dom.select(".newsletter-layout-locked .newsletter-layout-editable img").forEach((image) => {
                newsletterImageSources.set(image, image.getAttribute("src"))
            })
        })
        editor.on("NodeChange ObjectResized", () => {
            editor.dom.select(".newsletter-layout-locked .newsletter-layout-editable img").forEach(sizeNewLayoutImage)
        })

        layouts.forEach(([name, label, leftContent, rightContent]) => {
            editor.ui.registry.addButton(name, {
                text: label,
                tooltip: `Insert a fixed ${name === "newsletter_full_text" ? "one-column" : "two-column"} ${label.toLowerCase()} block`,
                onAction: () => editor.insertContent(name === "newsletter_full_text" ? fullTextBlock : layoutTable(leftContent, rightContent))
            })
        })
    }
}
