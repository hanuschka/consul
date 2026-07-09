import { Controller } from "@hotwired/stimulus"
import { Chart, registerables } from "chart.js"

Chart.register(...registerables)

const isPdfMode = () =>
  typeof document !== "undefined" &&
  document.body !== null &&
  document.body.classList.contains("evaluation-pdf-body")

if (isPdfMode()) {
  Chart.defaults.animation = false
}

export default class extends Controller {
  connect() {
    this.charts = []
    this.element.querySelectorAll("[data-area-chart]").forEach(el => this.registerChart(this.initAreaChart(el)))
    this.element.querySelectorAll("[data-bar-chart]").forEach(el => this.registerChart(this.initBarChart(el)))

    this.parentDetails = this.element.closest("details")
    if (this.parentDetails) this.parentDetails.addEventListener("toggle", this.handleDetailsToggle)

    document.addEventListener("adm-charts:resize", this.resizeCharts)
  }

  disconnect() {
    document.removeEventListener("adm-charts:resize", this.resizeCharts)

    if (this.parentDetails) this.parentDetails.removeEventListener("toggle", this.handleDetailsToggle)
    this.element.querySelectorAll("canvas").forEach(canvas => {
      Chart.getChart(canvas)?.destroy()
    })
  }

  registerChart(chart) {
    if (chart) this.charts.push(chart)
  }

  handleDetailsToggle = () => {
    if (this.parentDetails.open) this.resizeCharts()
  }

  resizeCharts = () => {
    this.charts.forEach(chart => chart.resize())
  }

  initAreaChart(container) {
    const canvas = container.querySelector("canvas")
    if (!canvas) return

    Chart.getChart(canvas)?.destroy()

    const labels = JSON.parse(container.dataset.chartLabels || "[]")
    const values = JSON.parse(container.dataset.chartValues || "[]")
    const color  = container.dataset.chartColor || "#6BA3D6"
    const ctx    = canvas.getContext("2d")

    const chart = new Chart(ctx, {
      type: "line",
      data: {
        labels,
        datasets: [{
          data: values,
          borderColor: color,
          backgroundColor: color + "30",
          borderWidth: 2,
          fill: true,
          tension: 0.3,
          pointRadius: 0,
          pointHoverRadius: 5,
          pointHoverBackgroundColor: color,
          pointHoverBorderColor: "#fff",
          pointHoverBorderWidth: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: "#333",
            titleColor: "#fff",
            bodyColor: "#fff",
            cornerRadius: 4,
            padding: 10,
            intersect: false,
            mode: "index"
          }
        },
        scales: {
          x: {
            grid: { display: false },
            ticks: { color: "#666", maxRotation: 0, autoSkip: true, maxTicksLimit: 6 },
            border: { display: false }
          },
          y: {
            grid: { color: "#e0e0e0" },
            ticks: { color: "#666", padding: 10 },
            border: { display: false },
            beginAtZero: true
          }
        },
        interaction: { intersect: false, mode: "index" }
      }
    })

    return chart
  }

  initBarChart(container) {
    const canvas = container.querySelector("canvas")
    if (!canvas) return

    Chart.getChart(canvas)?.destroy()

    const labels      = JSON.parse(container.dataset.chartLabels || "[]")
    const values      = JSON.parse(container.dataset.chartValues || "[]")
    const orientation = container.dataset.chartOrientation || "vertical"
    const color       = container.dataset.chartColors ? JSON.parse(container.dataset.chartColors) : "#6BA3D6"
    const isHorizontal = orientation === "horizontal"
    const ctx         = canvas.getContext("2d")

    if (isHorizontal) {
      const barHeight = 35
      const barSpacing = 12
      container.style.height = (labels.length * (barHeight + barSpacing) + 40) + "px"
    }

    const chart = new Chart(ctx, {
      type: "bar",
      data: {
        labels,
        datasets: [{
          data: values,
          backgroundColor: color,
          borderWidth: 0,
          borderRadius: 4,
          barThickness: isHorizontal ? 35 : 40
        }]
      },
      options: {
        indexAxis: isHorizontal ? "y" : "x",
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: "#333",
            titleColor: "#fff",
            bodyColor: "#fff",
            cornerRadius: 4,
            padding: 10
          }
        },
        scales: {
          x: { grid: { display: isHorizontal }, ticks: { color: "#333" }, border: { display: false } },
          y: { grid: { display: !isHorizontal }, ticks: { color: "#333" }, border: { display: false } }
        }
      }
    })

    return chart
  }
}
