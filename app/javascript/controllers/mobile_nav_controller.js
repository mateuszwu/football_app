import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer", "overlay"]

  open() {
    this.drawerTarget.hidden = false
    this.overlayTarget.hidden = false
    document.documentElement.classList.add("mobile-nav-open")
  }

  close() {
    this.drawerTarget.hidden = true
    this.overlayTarget.hidden = true
    document.documentElement.classList.remove("mobile-nav-open")
  }
}
