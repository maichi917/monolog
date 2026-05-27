// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"

document.addEventListener("change", (event) => {
  if (event.target.type !== "file") return

  const form = event.target.closest("form")
  const uploadProgress = form.querySelector("[data-upload-progress]")
  const imagePreview = form.querySelector("[data-image-preview]")
  const imagePreviewPlaceholder = form.querySelector("[data-image-preview-placeholder]")
  const file = event.target.files[0]

  if (uploadProgress) {
    uploadProgress.textContent = "画像が選択されました"
    uploadProgress.classList.remove("hidden")
  }

  if (imagePreview && file) {
    imagePreview.src = URL.createObjectURL(file)
    imagePreview.classList.remove("hidden")
    if (imagePreviewPlaceholder) {
      imagePreviewPlaceholder.classList.add("hidden")
    }
  }
})

document.addEventListener("submit", (event) => {
  const form = event.target
  const submitLoading = form.querySelector("[data-submit-loading]")
  const submitButton = form.querySelector("input[type='submit']")

  if (!submitLoading) return

  submitLoading.classList.remove("hidden")
  if (submitButton) {
    submitButton.disabled = true
  }
})

document.addEventListener("click", (event) => {
  const toggleButton = event.target.closest("[data-disclosure-toggle]")
  const cancelButton = event.target.closest("[data-disclosure-cancel]")
  const button = toggleButton || cancelButton

  if (!button) return

  const disclosure = button.closest("[data-disclosure]")
  const panel = disclosure?.querySelector("[data-disclosure-panel]")

  if (!panel) return

  panel.classList.toggle("hidden", Boolean(cancelButton))
})
