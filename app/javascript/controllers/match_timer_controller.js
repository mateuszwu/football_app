import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["clock"];
  static values = {
    finishedAt: String,
    startedAt: String,
    status: String
  };

  connect() {
    this.renderClock();

    if (this.statusValue !== "in_progress" || !this.hasStartedAtValue) {
      return;
    }

    this.interval = window.setInterval(() => {
      this.renderClock();
    }, 1000);
  }

  disconnect() {
    if (this.interval) {
      window.clearInterval(this.interval);
    }
  }

  renderClock() {
    this.clockTarget.textContent = this.formattedDuration();
  }

  formattedDuration() {
    if (!this.hasStartedAtValue) {
      return "00:00";
    }

    const startedAt = new Date(this.startedAtValue);
    const endTime = this.statusValue === "finished" && this.hasFinishedAtValue ? new Date(this.finishedAtValue) : new Date();
    const elapsedSeconds = Math.max(Math.floor((endTime - startedAt) / 1000), 0);
    const minutes = Math.floor(elapsedSeconds / 60);
    const seconds = elapsedSeconds % 60;

    return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
  }
}
