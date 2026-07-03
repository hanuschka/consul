(function() {
  "use strict";

  App.AreaChartComponent = {
    initialize: function() {
      var charts = document.querySelectorAll("[data-area-chart]");
      charts.forEach(this.initChart.bind(this));
    },

    initChart: function(container) {
      if (container.dataset.chartInitialized === "true") {
        return;
      }

      var canvas = container.querySelector("canvas");
      if (!canvas) {
        return;
      }

      var labels = JSON.parse(container.dataset.chartLabels || "[]");
      var values = JSON.parse(container.dataset.chartValues || "[]");
      var color = container.dataset.chartColor || "#6BA3D6";

      var ctx = canvas.getContext("2d");

      var gradient = ctx.createLinearGradient(0, 0, 0, 300);
      gradient.addColorStop(0, color + "80");
      gradient.addColorStop(1, color + "10");

      var chartConfig = {
        type: "line",
        data: {
          labels: labels,
          datasets: [{
            data: values,
            borderColor: color,
            backgroundColor: gradient,
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
            legend: {
              display: false
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
              intersect: false,
              mode: "index"
            }
          },
          scales: {
            x: {
              grid: {
                display: false
              },
              ticks: {
                color: "#666",
                font: {
                  size: 13
                },
                maxRotation: 0,
                autoSkip: true,
                maxTicksLimit: 6
              },
              border: {
                display: false
              }
            },
            y: {
              grid: {
                color: "#e0e0e0",
                drawBorder: false
              },
              ticks: {
                color: "#666",
                font: {
                  size: 13
                },
                padding: 10
              },
              border: {
                display: false
              },
              beginAtZero: true
            }
          },
          interaction: {
            intersect: false,
            mode: "index"
          }
        }
      };

      App.ChartLoadingPlaceholder.markWhenRendered(chartConfig, container);

      new Chart(ctx, chartConfig);
      container.dataset.chartInitialized = "true";
    }
  };
}).call(this);

