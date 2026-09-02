(function() {
  "use strict";

  App.PieChartComponent = {
    initialize: function() {
      const charts = document.querySelectorAll("[data-pie-chart]");
      charts.forEach(this.initChart.bind(this));
    },

    initChart: function(container) {
      if (container.dataset.chartInitialized === "true") {
        return;
      }

      const canvas = container.querySelector("canvas");
      if (!canvas) {
        return;
      }

      const chartData = this.getChartData(container);
      const ctx = canvas.getContext("2d");
      const chartConfig = this.createChartConfig(chartData);

      App.ChartLoadingPlaceholder.markWhenRendered(chartConfig, container);

      new Chart(ctx, chartConfig);
      container.dataset.chartInitialized = "true";
    },

    getChartData: function(container) {
      const labels = JSON.parse(container.dataset.chartLabels || "[]");
      const values = JSON.parse(container.dataset.chartValues || "[]");
      const colors = container.dataset.chartColors
        ? JSON.parse(container.dataset.chartColors)
        : this.getDefaultColors(labels.length);
      const hideLegend = container.dataset.chartHideLegend === "true";
      const labelsAtEdges = container.dataset.chartLabelsAtEdges === "true";

      return {
        labels: labels,
        values: values,
        colors: colors,
        showLegend: !hideLegend,
        labelsAtEdges: labelsAtEdges
      };
    },

    getDefaultColors: function(count) {
      const palette = [
        "#5B9BD5",
        "#ED7D31",
        "#A5A5A5",
        "#70AD47",
        "#FFC000",
        "#4472C4",
        "#9E480E",
        "#636363"
      ];

      return Array.from({ length: count }, (_, i) => palette[i % palette.length]);
    },

    createChartConfig: function(chartData) {
      const datalabelsConfig = chartData.labelsAtEdges
        ? {
            color: "#fff",
            font: {
              size: 14,
              weight: "bold"
            },
            anchor: "end",
            align: "start",
            offset: 10,
            formatter: (value, context) => {
              const total = context.dataset.data.reduce((a, b) => a + b, 0);
              const percentage = ((value / total) * 100).toFixed(1);
              return percentage > 3 ? `${percentage}%` : "";
            }
          }
        : {
            color: "#fff",
            font: {
              size: 16,
              weight: "bold"
            },
            anchor: "center",
            align: "center",
            formatter: (value, context) => {
              const total = context.dataset.data.reduce((a, b) => a + b, 0);
              const percentage = ((value / total) * 100).toFixed(1);
              return percentage > 5 ? `${percentage}%` : "";
            }
          };

      return {
        type: "pie",
        plugins: [ChartDataLabels],
        data: {
          labels: chartData.labels,
          datasets: [{
            data: chartData.values,
            backgroundColor: chartData.colors,
            borderWidth: 2,
            borderColor: "#fff"
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: {
              display: chartData.showLegend,
              position: "bottom",
              labels: {
                padding: 15,
                font: {
                  size: 14
                },
                color: "#333",
                usePointStyle: true,
                pointStyle: "circle"
              }
            },
            tooltip: {
              backgroundColor: "#333",
              titleColor: "#fff",
              bodyColor: "#fff",
              cornerRadius: 4,
              padding: 10,
              titleFont: {
                size: 14
              },
              bodyFont: {
                size: 14
              },
              callbacks: {
                label: (context) => {
                  const label = context.label || "";
                  const value = context.parsed || 0;
                  const total = context.dataset.data.reduce((a, b) => a + b, 0);
                  const percentage = ((value / total) * 100).toFixed(1);
                  return `${label}: ${value} (${percentage}%)`;
                }
              }
            },
            datalabels: datalabelsConfig
          }
        }
      };
    }
  };
}).call(this);
