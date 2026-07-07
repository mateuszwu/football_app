import { Controller } from "@hotwired/stimulus"
import cytoscape from "cytoscape"

export default class extends Controller {
  static values = {
    data: Object
  }

  connect() {
    if (!this.dataValue || !this.dataValue.elements || this.dataValue.elements.length === 0) return

    this.tooltip = this.buildTooltip()
    this.cy = cytoscape({
      container: this.element,
      elements: this.dataValue.elements,
      style: this.styles(),
      layout: this.layoutOptions(),
      wheelSensitivity: 0.2
    })

    this.cy.on("tap", "node", (event) => {
      const profilePath = event.target.data("profile_path")
      if (profilePath) window.location.href = profilePath
    })

    this.cy.on("tap", "edge", (event) => {
      this.showEdgeTooltip(event)
    })

    this.cy.on("tap", (event) => {
      if (event.target === this.cy) this.hideTooltip()
    })

    this.cy.on("mouseover", "node", (event) => {
      this.showNodeTooltip(event)
    })

    this.cy.on("mouseover", "edge", (event) => {
      this.showEdgeTooltip(event)
    })

    this.cy.on("mouseout", "node, edge", () => {
      this.hideTooltip()
    })

    this.cy.on("mousemove", "node, edge", (event) => {
      this.positionTooltip(event.renderedPosition)
    })
  }

  disconnect() {
    this.hideTooltip()
    if (this.tooltip) this.tooltip.remove()

    if (!this.cy) return

    this.cy.destroy()
    this.cy = null
    this.tooltip = null
  }

  layoutOptions() {
    return {
      name: "cose",
      animate: false,
      fit: true,
      padding: 44,
      nodeRepulsion: 9900,
      idealEdgeLength: 132,
      edgeElasticity: 81,
      gravity: 0.25,
      numIter: 1000
    }
  }

  styles() {
    return [
      {
        selector: "node",
        style: {
          "background-color": "#14351F",
          "border-color": "#7CFF3A",
          "border-width": 2,
          "label": "data(label)",
          "color": "#F8FAFC",
          "font-size": 12,
          "font-weight": "700",
          "text-valign": "center",
          "text-halign": "center",
          "width": 42,
          "height": 42
        }
      },
      {
        selector: "node:active",
        style: {
          "overlay-color": "#7CFF3A",
          "overlay-opacity": 0.12
        }
      },
      {
        selector: "node:selected",
        style: {
          "background-color": "#1F5F2E",
          "border-color": "#7CFF3A",
          "border-width": 4
        }
      },
      {
        selector: "edge",
        style: {
          "width": "data(width)",
          "line-color": "#64748B",
          "curve-style": "bezier",
          "opacity": 0.72,
          "text-background-color": "#020617",
          "text-background-opacity": 0,
          "text-background-padding": 4,
          "text-background-shape": "roundrectangle",
          "text-border-color": "rgba(124, 255, 58, 0.4)",
          "text-border-opacity": 0,
          "text-border-width": 1
        }
      },
      {
        selector: "edge:selected",
        style: {
          "label": "data(shared_matches)",
          "color": "#F8FAFC",
          "font-size": 12,
          "font-weight": "900",
          "text-background-opacity": 0.92,
          "text-border-opacity": 1,
          "opacity": 0.95,
          "z-index": 3
        }
      },
      {
        selector: "edge[color_group = 'high']",
        style: {
          "line-color": "#22C55E"
        }
      },
      {
        selector: "edge[color_group = 'medium']",
        style: {
          "line-color": "#A3E635"
        }
      },
      {
        selector: "edge[color_group = 'low']",
        style: {
          "line-color": "#EF4444"
        }
      },
      {
        selector: "edge[color_group = 'hidden']",
        style: {
          "opacity": 0,
          "events": "no"
        }
      }
    ]
  }

  buildTooltip() {
    const tooltip = document.createElement("div")
    tooltip.className = "synergy-graph-tooltip"
    tooltip.setAttribute("role", "tooltip")
    tooltip.hidden = true
    this.element.appendChild(tooltip)

    return tooltip
  }

  showNodeTooltip(event) {
    if (!this.tooltip) return

    this.tooltip.textContent = event.target.data("name")
    this.tooltip.hidden = false
    this.element.classList.add("synergy-graph-network--hovering")
    this.positionTooltip(event.renderedPosition)
  }

  showEdgeTooltip(event) {
    if (!this.tooltip) return

    const sharedMatches = event.target.data("shared_matches")
    this.tooltip.textContent = this.sharedMatchesLabel(sharedMatches)
    this.tooltip.hidden = false
    this.element.classList.add("synergy-graph-network--hovering")
    this.positionTooltip(event.renderedPosition)
  }

  hideTooltip() {
    if (!this.tooltip) return

    this.tooltip.hidden = true
    this.element.classList.remove("synergy-graph-network--hovering")
  }

  positionTooltip(position) {
    if (!this.tooltip || this.tooltip.hidden || !position) return

    this.tooltip.style.left = `${position.x}px`
    this.tooltip.style.top = `${position.y}px`
  }

  sharedMatchesLabel(value) {
    const count = Number(value)
    if (count === 1) return "1 wspólny mecz"
    if ([2, 3, 4].includes(count)) return `${count} wspólne mecze`

    return `${count} wspólnych meczów`
  }
}
