import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    type: String,
    data: Object,
    options: Object
  }

  connect() {
    if (!window.Chart || !this.hasDataValue) return

    this.canvas = document.createElement("canvas")
    this.element.replaceChildren(this.canvas)
    this.chart = new window.Chart(this.canvas, {
      type: this.chartType(),
      data: this.chartData(),
      options: this.chartOptions()
    })
  }

  disconnect() {
    if (!this.chart) return

    this.chart.destroy()
    this.chart = null
  }

  chartType() {
    if (this.typeValue === "doughnut") return "doughnut"
    if (this.typeValue === "bar") return "bar"

    return "line"
  }

  chartData() {
    if (this.typeValue === "doughnut") {
      return {
        labels: this.dataValue.labels || [],
        datasets: this.dataValue.datasets || [
          {
            data: this.dataValue.values || [],
            backgroundColor: ["#22C55E", "#94A3B8", "#F97316"],
            borderColor: "#0B1728"
          }
        ]
      }
    }

    const datasets = (this.dataValue.datasets || []).map((dataset) => ({
      borderWidth: 2,
      pointRadius: 3,
      pointHoverRadius: 5,
      fill: false,
      ...dataset,
      stepped: this.typeValue === "stepped-line" ? true : dataset.stepped
    }))

    return {
      labels: this.dataValue.labels || [],
      datasets
    }
  }

  chartOptions() {
    const baseOptions = {
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
          bodyColor: "#CBD5E1",
          callbacks: {
            afterBody: (items) => this.tooltipMeta(items)
          }
        }
      },
      scales: {
        x: {
          grid: { color: "rgba(148, 163, 184, 0.1)" },
          ticks: { color: "#94A3B8", maxRotation: 0 }
        },
        y: {
          grid: { color: "rgba(148, 163, 184, 0.12)" },
          ticks: { color: "#94A3B8", precision: 0 }
        }
      }
    }

    if (this.typeValue === "doughnut") {
      delete baseOptions.scales
      baseOptions.cutout = "68%"
    }

    return this.mergeOptions(baseOptions, this.hasOptionsValue ? this.optionsValue : {})
  }

  tooltipMeta(items) {
    if (!items.length || !this.dataValue.points_meta) return []

    const meta = this.dataValue.points_meta[items[0].dataIndex]
    if (!meta) return []

    const delta = Number(meta.delta || 0)
    const symbol = delta > 0 ? "↗" : delta < 0 ? "↘" : "→"

    return [
      `ELO: ${meta.after || "—"}`,
      `${symbol} ${delta > 0 ? "+" : ""}${delta}`,
      meta.score ? `Wynik: ${meta.score}` : null,
      meta.result ? `Rezultat: ${meta.result.toUpperCase()}` : null
    ].filter(Boolean)
  }

  mergeOptions(base, extra) {
    return {
      ...base,
      ...extra,
      plugins: {
        ...base.plugins,
        ...(extra.plugins || {})
      },
      scales: extra.scales === undefined ? base.scales : {
        ...(base.scales || {}),
        ...extra.scales
      }
    }
  }
}
