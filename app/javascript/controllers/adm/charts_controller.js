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
    this.element.querySelectorAll("[data-pie-chart]").forEach(el => this.registerChart(this.initPieChart(el)))

    this.parentDetails = this.element.closest("details")
    if (this.parentDetails) this.parentDetails.addEventListener("toggle", this.handleDetailsToggle)

    document.addEventListener("adm-charts:resize", this.resizeCharts)
    this.element.addEventListener("adm-charts:datasets-changed", this.handleDatasetsChanged)
  }

  disconnect() {
    document.removeEventListener("adm-charts:resize", this.resizeCharts)
    this.element.removeEventListener("adm-charts:datasets-changed", this.handleDatasetsChanged)

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

  handleDatasetsChanged = (event) => {
    const card = event.target.closest(".adm-chart-card")
    if (!card) return

    const activeButton = card.querySelector("[data-granularity].-active")
    if (!activeButton) return

    this.applyGranularity(card, activeButton.dataset.granularity)
  }

  setGranularity(event) {
    const button = event.currentTarget
    const card = button.closest(".adm-chart-card")
    if (!card) return

    this.applyGranularity(card, button.dataset.granularity)
  }

  applyGranularity(card, granularity) {
    const wrapper = card.querySelector("[data-chart-datasets]")
    const canvas = wrapper?.querySelector("canvas")
    const chart = canvas ? Chart.getChart(canvas) : null
    if (!chart) return

    const datasets = JSON.parse(wrapper.dataset.chartDatasets || "{}")
    const series = datasets[granularity]
    if (!series) return

    chart.data.labels = series.labels
    chart.data.datasets[0].data = series.values
    chart.update()

    wrapper.dataset.chartLabels = JSON.stringify(series.labels)
    wrapper.dataset.chartValues = JSON.stringify(series.values)

    const total = card.querySelector(".adm-chart-card__total")
    if (total) {
      const sum = series.values.reduce((acc, value) => acc + value, 0)
      total.textContent = sum.toLocaleString(document.documentElement.lang || "de-DE")
    }

    card.querySelectorAll("[data-granularity]").forEach(btn => {
      const active = btn.dataset.granularity === granularity
      btn.classList.toggle("-active", active)
      btn.setAttribute("aria-pressed", active)
    })
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

  initPieChart(container) {
    const canvas = container.querySelector("canvas")
    if (!canvas) return

    Chart.getChart(canvas)?.destroy()

    const labels = JSON.parse(container.dataset.chartLabels || "[]")
    const values = JSON.parse(container.dataset.chartValues || "[]")
    const colors = container.dataset.chartColors
      ? JSON.parse(container.dataset.chartColors)
      : ["#6BA3D6", "#E8A87C", "#C9CBCF"]
    const ctx = canvas.getContext("2d")

    return new Chart(ctx, {
      type: "pie",
      data: {
        labels,
        datasets: [{ data: values, backgroundColor: colors, borderColor: "#fff", borderWidth: 2 }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { position: "bottom", labels: { color: "#333", boxWidth: 12, padding: 12 } },
          tooltip: {
            backgroundColor: "#333",
            titleColor: "#fff",
            bodyColor: "#fff",
            cornerRadius: 4,
            padding: 10
          }
        }
      }
    })
  }

  initBarChart(container) {
    const canvas = container.querySelector("canvas")
    if (!canvas) return

    Chart.getChart(canvas)?.destroy()

    const labels      = JSON.parse(container.dataset.chartLabels || "[]")
    const values      = JSON.parse(container.dataset.chartValues || "[]")
    const series      = container.dataset.chartSeries ? JSON.parse(container.dataset.chartSeries) : null
    const orientation = container.dataset.chartOrientation || "vertical"
    const color       = container.dataset.chartColors ? JSON.parse(container.dataset.chartColors) : "#6BA3D6"
    const stacked     = container.dataset.chartStacked === "true"
    const isHorizontal = orientation === "horizontal"
    const ctx         = canvas.getContext("2d")

    if (isHorizontal) {
      const barHeight = 35
      const barSpacing = 12
      container.style.height = (labels.length * (barHeight + barSpacing) + 40) + "px"
    }

    const barThickness = isHorizontal ? 35 : 40
    const datasets = series
      ? series.map(entry => ({
          label: entry.label,
          data: entry.values,
          backgroundColor: entry.color,
          borderWidth: 0,
          borderRadius: 4,
          barThickness
        }))
      : [{
          data: values,
          backgroundColor: color,
          borderWidth: 0,
          borderRadius: 4,
          barThickness
        }]
    const showLegend = series !== null && series.length > 1

    const chart = new Chart(ctx, {
      type: "bar",
      data: {
        labels,
        datasets
      },
      options: {
        indexAxis: isHorizontal ? "y" : "x",
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: showLegend,
            position: "bottom",
            labels: { color: "#333", boxWidth: 12, padding: 12 }
          },
          tooltip: {
            backgroundColor: "#333",
            titleColor: "#fff",
            bodyColor: "#fff",
            cornerRadius: 4,
            padding: 10
          }
        },
        scales: {
          x: { stacked, grid: { display: isHorizontal }, ticks: { color: "#333" }, border: { display: false } },
          y: { stacked, grid: { display: !isHorizontal }, ticks: { color: "#333" }, border: { display: false } }
        }
      }
    })

    return chart
  }
}
