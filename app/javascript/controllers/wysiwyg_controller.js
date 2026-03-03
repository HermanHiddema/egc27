import { Controller } from "@hotwired/stimulus"
import Quill from "quill"

export default class extends Controller {
    static targets = ["input", "editor"]

    connect() {
        if (!this.hasInputTarget || !this.hasEditorTarget) return

        this.quill = new Quill(this.editorTarget, {
            theme: "snow",
            modules: {
                toolbar: [
                    [{ header: [1, 2, 3, false] }],
                    ["bold", "italic", "underline"],
                    [{ list: "ordered" }, { list: "bullet" }],
                    ["blockquote", "code-block", "link"],
                    ["clean"]
                ]
            }
        })

        this.quill.root.innerHTML = this.inputTarget.value || ""

        this.syncContent = () => {
            this.inputTarget.value = this.quill.getText().trim().length === 0 ? "" : this.quill.root.innerHTML
        }

        this.quill.on("text-change", this.syncContent)
    }

    disconnect() {
        if (!this.quill || !this.syncContent) return

        this.quill.off("text-change", this.syncContent)
    }
}