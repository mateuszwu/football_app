import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    type: String,
    data: Object
  }

  connect() {
    if (!window.Chart || !this.hasDataValue) return

    this.canvas = document.createElement("canvas")
    this.element.replaceChildren(this.canvas)
    this.chart = new window.Chart(this.canvas, {
      type: this.typeValue || "bar",
      data: this.chartData(),
      options: this.chartOptions()
    })
  }

  disconnect() {
    if (!this.chart) return

    this.chart.destroy()
    this.chart = null
  }

  chartData() {
    return {
      labels: this.dataValue.labels || [],
      datasets: (this.dataValue.datasets || []).map((dataset) => ({
        borderWidth: 2,
        borderRadius: this.typeValue === "bar" ? 8 : 0,
        ...dataset
      }))
    }
  }

  chartOptions() {
    const options = {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          labels: {
            color: "#CBD5E1",
            boxWidth: 10,
            usePointStyle: true
          }
        },
        tooltip: {
          backgroundColor: "#020617",
          borderColor: "rgba(148, 163, 184, 0.24)",
          borderWidth: 1,
          titleColor: "#F8FAFC",
          bodyColor: "#CBD5E1"
        }
      },
      scales: {
        x: {
          grid: { color: "rgba(148, 163, 184, 0.08)" },
          ticks: { color: "#94A3B8", maxRotation: 0 }
        },
        y: {
          grid: { color: "rgba(148, 163, 184, 0.12)" },
          ticks: { color: "#94A3B8", precision: 0 }
        }
      }
    }

    if (this.typeValue === "doughnut") {
      delete options.scales
      options.cutout = "68%"
    }

    return options
  }
}
