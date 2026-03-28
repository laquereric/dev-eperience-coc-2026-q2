import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["title", "modelPanel", "viewPanel", "controllerPanel", "agenticPanel", "bankList"]
  static values = { introspectUrl: String }

  connect() {
    this.data_ = this.parseData()
    this.rewriteLinks()
    document.addEventListener("contextmenu", this.handleContextMenu)
    document.addEventListener("keydown", this.handleKeydown)
  }

  disconnect() {
    document.removeEventListener("contextmenu", this.handleContextMenu)
    document.removeEventListener("keydown", this.handleKeydown)
  }

  parseData() {
    const el = document.getElementById("dx-mirror-data")
    if (!el) return {}
    try {
      return JSON.parse(el.textContent)
    } catch {
      return {}
    }
  }

  handleContextMenu = (event) => {
    event.preventDefault()

    const context = this.findAnnotation(event.target)
    this.populateModelPanel()
    this.populateViewPanel(context)
    this.populateControllerPanel()
    this.updateTitle(context)

    this.showTab("model")
    this.show()
  }

  handleKeydown = (event) => {
    if (event.key === "Escape") this.dismiss()
  }

  findAnnotation(target) {
    let node = target
    while (node && node !== document.body) {
      const prev = this.walkCommentsBackward(node)
      if (prev) return prev
      node = node.parentElement
    }
    return null
  }

  walkCommentsBackward(node) {
    let sibling = node.previousSibling
    while (sibling) {
      if (sibling.nodeType === Node.COMMENT_NODE) {
        const text = sibling.textContent.trim()
        if (text.startsWith("dx:partial:")) {
          return { type: "partial", path: text.replace("dx:partial:", "") }
        }
        if (text.startsWith("dx:component:")) {
          return { type: "component", name: text.replace("dx:component:", "") }
        }
      }
      sibling = sibling.previousSibling
    }
    return null
  }

  updateTitle(context) {
    if (!this.hasTitleTarget) return
    if (context) {
      const label = context.type === "partial" ? context.path : context.name
      this.titleTarget.textContent = `Source: ${label}`
    } else {
      this.titleTarget.textContent = "Source Inspector"
    }
  }

  populateModelPanel() {
    // Model panel is server-rendered in the overlay HTML
  }

  populateViewPanel(context) {
    // View panel is server-rendered; highlight active context if found
    if (!context || !this.hasViewPanelTarget) return
    const highlight = context.type === "partial" ? context.path : context.name
    const links = this.viewPanelTarget.querySelectorAll("code")
    links.forEach(el => {
      el.classList.toggle("dx-mirror-highlight-text", el.textContent.includes(highlight))
    })
  }

  populateControllerPanel() {
    // Controller panel is server-rendered in the overlay HTML
  }

  switchTab(event) {
    const tab = event.currentTarget.dataset.tab
    this.showTab(tab)
  }

  showTab(name) {
    const overlay = this.element
    overlay.querySelectorAll(".dx-mirror-tab").forEach(btn => {
      btn.classList.toggle("dx-mirror-tab-active", btn.dataset.tab === name)
    })
    overlay.querySelectorAll(".dx-mirror-panels [data-panel]").forEach(panel => {
      panel.style.display = panel.dataset.panel === name ? "" : "none"
    })
  }

  async recallBank(event) {
    const bankId = event.currentTarget.dataset.bankId
    const resultsEl = this.element.querySelector(`[data-bank-results="${bankId}"]`)
    if (!resultsEl) return

    resultsEl.innerHTML = '<p class="dx-mirror-muted">Loading...</p>'

    const query = this.buildQuery()
    try {
      const response = await fetch(this.introspectUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body: JSON.stringify({ bank_id: bankId, query: query })
      })
      const data = await response.json()
      resultsEl.innerHTML = this.renderMemories(data)
    } catch (error) {
      resultsEl.innerHTML = `<p class="dx-mirror-warning">Error: ${error.message}</p>`
    }
  }

  buildQuery() {
    const ctrl = this.data_.controller || {}
    const models = Object.keys(this.data_.models || {})
    return `${ctrl.class_name}#${ctrl.action} with models: ${models.join(", ")}`
  }

  renderMemories(data) {
    if (!data || (!data.memories && !data.results)) {
      return '<p class="dx-mirror-muted">No memories found.</p>'
    }
    const items = data.memories || data.results || []
    if (items.length === 0) {
      return '<p class="dx-mirror-muted">No memories found.</p>'
    }
    return '<ul class="dx-mirror-memory-list">' +
      items.map(m => {
        const content = m.content || m.text || JSON.stringify(m)
        return `<li class="dx-mirror-memory-item"><pre>${this.escapeHtml(content)}</pre></li>`
      }).join("") +
      "</ul>"
  }

  sendChat() {
    const input = this.element.querySelector(".dx-mirror-chat-input")
    if (!input || !input.value.trim()) return

    const question = input.value.trim()
    const chatArea = input.closest(".dx-mirror-chat")
    const resultsEl = chatArea.querySelector(".dx-mirror-chat-results") || (() => {
      const el = document.createElement("div")
      el.className = "dx-mirror-chat-results"
      chatArea.appendChild(el)
      return el
    })()

    resultsEl.innerHTML = '<p class="dx-mirror-muted">Thinking...</p>'
    input.value = ""

    const context = this.buildQuery()
    fetch(this.introspectUrlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfToken()
      },
      body: JSON.stringify({ query: `${context} — ${question}`, chat: true })
    })
      .then(r => r.json())
      .then(data => {
        const answer = data.answer || data.text || "No response received."
        resultsEl.innerHTML = `<div class="dx-mirror-chat-answer"><pre>${this.escapeHtml(answer)}</pre></div>`
      })
      .catch(err => {
        resultsEl.innerHTML = `<p class="dx-mirror-warning">Error: ${err.message}</p>`
      })
  }

  show() {
    this.element.style.display = ""
  }

  dismiss() {
    this.element.style.display = "none"
  }

  rewriteLinks() {
    document.addEventListener("click", (event) => {
      const link = event.target.closest("a[href]")
      if (!link) return

      const href = link.getAttribute("href")
      if (!href || href.startsWith("/dx/mirror") || href.startsWith("http") || href.startsWith("#") || href.startsWith("vscode://")) return

      if (href.startsWith("/")) {
        event.preventDefault()
        window.location.href = `/dx/mirror${href}`
      }
    })
  }

  csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.content : ""
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
