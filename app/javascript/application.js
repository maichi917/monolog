// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"

const ALLOWED_IMAGE_TYPES = ["image/jpeg", "image/png"]
const MAX_IMAGE_SIZE_BYTES = 10 * 1024 * 1024

document.addEventListener("change", (event) => {
  if (event.target.type !== "file") return

  const form = event.target.closest("form")
  const uploadProgress = form.querySelector("[data-upload-progress]")
  const imagePreview = form.querySelector("[data-image-preview]")
  const imagePreviewPlaceholder = form.querySelector("[data-image-preview-placeholder]")
  const file = event.target.files[0]

  if (!file) return

  if (!ALLOWED_IMAGE_TYPES.includes(file.type)) {
    event.target.value = ""
    if (uploadProgress) {
      uploadProgress.textContent = "JPEGまたはPNG形式の画像を選択してください"
      uploadProgress.classList.remove("hidden", "alert-success")
      uploadProgress.classList.add("alert-error")
    }
    return
  }

  if (file.size > MAX_IMAGE_SIZE_BYTES) {
    event.target.value = ""
    if (uploadProgress) {
      uploadProgress.textContent = "画像は10MB以下にしてください"
      uploadProgress.classList.remove("hidden", "alert-success")
      uploadProgress.classList.add("alert-error")
    }
    return
  }

  if (uploadProgress) {
    uploadProgress.textContent = "画像が選択されました"
    uploadProgress.classList.remove("hidden", "alert-error")
    uploadProgress.classList.add("alert-success")
  }

  if (imagePreview) {
    imagePreview.src = URL.createObjectURL(file)
    imagePreview.classList.remove("hidden")
    if (imagePreviewPlaceholder) {
      imagePreviewPlaceholder.classList.add("hidden")
    }
  }
})

document.addEventListener("change", (event) => {
  if (!event.target.matches("[data-unknown-date-toggle]")) return

  const dateInput = event.target.closest("form")?.querySelector("[data-unknown-date-field]")
  if (dateInput) dateInput.disabled = event.target.checked
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

const AUTOCOMPLETE_MIN_LENGTH = 2
const AUTOCOMPLETE_DEBOUNCE_MS = 300
const AUTOCOMPLETE_ITEM_CLASS =
  "cursor-pointer px-3 py-2 text-sm text-slate-700 hover:bg-emerald-50 aria-selected:bg-emerald-100"
const autocompleteTimers = new WeakMap()

function closeAutocompleteList(list) {
  list.innerHTML = ""
  list.classList.add("hidden")
}

function renderAutocompleteList(list, names) {
  if (names.length === 0) {
    closeAutocompleteList(list)
    return
  }

  list.innerHTML = ""
  names.forEach((name) => {
    const item = document.createElement("li")
    item.textContent = name
    item.setAttribute("role", "option")
    item.setAttribute("aria-selected", "false")
    item.dataset.autocompleteItem = "true"
    item.className = AUTOCOMPLETE_ITEM_CLASS
    list.appendChild(item)
  })

  list.classList.remove("hidden")
}

document.addEventListener("input", (event) => {
  const input = event.target
  if (!input.matches("[data-autocomplete-input]")) return

  const list = input.closest("[data-autocomplete-container]")?.querySelector("[data-autocomplete-list]")
  if (!list) return

  clearTimeout(autocompleteTimers.get(input))

  const query = input.value.trim()
  if (query.length < AUTOCOMPLETE_MIN_LENGTH) {
    closeAutocompleteList(list)
    return
  }

  autocompleteTimers.set(
    input,
    setTimeout(() => {
      list.innerHTML = "<li class=\"px-3 py-2 text-sm text-slate-400\">検索中...</li>"
      list.classList.remove("hidden")

      fetch(`/items/autocomplete?q=${encodeURIComponent(query)}`, { headers: { Accept: "application/json" } })
        .then((response) => response.json())
        .then((names) => renderAutocompleteList(list, names))
        .catch(() => closeAutocompleteList(list))
    }, AUTOCOMPLETE_DEBOUNCE_MS)
  )
})

document.addEventListener("keydown", (event) => {
  if (!event.target.matches("[data-autocomplete-input]")) return

  const list = event.target.closest("[data-autocomplete-container]")?.querySelector("[data-autocomplete-list]")
  if (!list || list.classList.contains("hidden")) return

  const items = Array.from(list.querySelectorAll("[data-autocomplete-item]"))
  if (items.length === 0) return

  const activeIndex = items.findIndex((item) => item.getAttribute("aria-selected") === "true")

  if (event.key === "ArrowDown" || event.key === "ArrowUp") {
    event.preventDefault()
    const step = event.key === "ArrowDown" ? 1 : -1
    const nextIndex = (activeIndex + step + items.length) % items.length
    items.forEach((item) => item.setAttribute("aria-selected", "false"))
    items[nextIndex].setAttribute("aria-selected", "true")
    items[nextIndex].scrollIntoView({ block: "nearest" })
  } else if (event.key === "Enter" && activeIndex >= 0) {
    event.preventDefault()
    event.target.value = items[activeIndex].textContent
    closeAutocompleteList(list)
  } else if (event.key === "Escape") {
    closeAutocompleteList(list)
  }
})

document.addEventListener("click", (event) => {
  const selectedItem = event.target.closest("[data-autocomplete-item]")
  if (selectedItem) {
    const list = selectedItem.closest("[data-autocomplete-list]")
    const input = selectedItem.closest("[data-autocomplete-container]")?.querySelector("[data-autocomplete-input]")
    if (input) input.value = selectedItem.textContent
    closeAutocompleteList(list)
    return
  }

  document.querySelectorAll("[data-autocomplete-container]").forEach((container) => {
    if (container.contains(event.target)) return

    const list = container.querySelector("[data-autocomplete-list]")
    if (list) closeAutocompleteList(list)
  })
})
