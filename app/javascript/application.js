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
  const stepperButton = event.target.closest("[data-stock-stepper-action]")
  if (stepperButton) {
    const stepper = stepperButton.closest("[data-stock-stepper]")
    const input = stepper?.querySelector("[data-stock-stepper-input]")
    if (!input) return

    const currentValue = Number.parseInt(input.value || "0", 10)
    const direction = stepperButton.dataset.stockStepperAction === "increment" ? 1 : -1
    input.value = Math.max(0, currentValue + direction)
    input.dispatchEvent(new Event("change", { bubbles: true }))
    return
  }

  const toggleButton = event.target.closest("[data-disclosure-toggle]")
  const cancelButton = event.target.closest("[data-disclosure-cancel]")
  const button = toggleButton || cancelButton

  if (!button) return

  const disclosure = button.closest("[data-disclosure]")
  const target = button.dataset.disclosureTarget
  const panel =
    cancelButton?.closest("[data-disclosure-panel]") ||
    disclosure?.querySelector(target ? `[data-disclosure-panel="${target}"]` : "[data-disclosure-panel]")

  if (!panel) return

  if (panel.matches("[data-modal-panel]")) {
    panel.classList.toggle("hidden", Boolean(cancelButton))
    panel.classList.toggle("flex", Boolean(toggleButton))
    button.setAttribute("aria-expanded", String(Boolean(toggleButton)))
    document.body.classList.toggle("overflow-hidden", Boolean(toggleButton))
    return
  }

  panel.classList.toggle("hidden", Boolean(cancelButton))
  button.setAttribute("aria-expanded", String(Boolean(toggleButton)))
})

document.addEventListener("keydown", (event) => {
  if (event.key !== "Escape") return

  document.querySelectorAll("[data-modal-panel]:not(.hidden)").forEach((panel) => {
    panel.classList.add("hidden")
    panel.classList.remove("flex")
  })
  document.body.classList.remove("overflow-hidden")
})
