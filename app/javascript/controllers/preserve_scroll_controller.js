import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.captureIntent = this.captureIntent.bind(this)
    this.storeScroll = this.storeScroll.bind(this)
    this.restoreScroll = this.restoreScroll.bind(this)

    this.element.addEventListener("click", this.captureIntent, { capture: true })
    this.element.addEventListener("turbo:click", this.storeScroll)
    this.element.addEventListener("submit", this.storeScroll, { capture: true })
    this.element.addEventListener("turbo:before-fetch-request", this.storeScroll)
    this.element.addEventListener("turbo:frame-load", this.restoreScroll)
    this.restoreScroll()
  }

  disconnect() {
    this.element.removeEventListener("click", this.captureIntent, { capture: true })
    this.element.removeEventListener("turbo:click", this.storeScroll)
    this.element.removeEventListener("submit", this.storeScroll, { capture: true })
    this.element.removeEventListener("turbo:before-fetch-request", this.storeScroll)
    this.element.removeEventListener("turbo:frame-load", this.restoreScroll)
  }

  captureIntent(event) {
    if (!event.target.closest("a[href]")) return

    this.storeScroll()
  }

  storeScroll() {
    window[this.storageKey] = window.scrollY
  }

  restoreScroll() {
    const scrollY = window[this.storageKey]
    if (scrollY === undefined) return

    delete window[this.storageKey]

    this.restoreAt(scrollY, 0)
    this.restoreAt(scrollY, 50)
    this.restoreAt(scrollY, 150)
  }

  restoreAt(scrollY, delay) {
    setTimeout(() => {
      window.scrollTo(window.scrollX, Number(scrollY))
    }, delay)
  }

  get storageKey() {
    return `__preserveScroll:${this.element.id}`
  }
}
