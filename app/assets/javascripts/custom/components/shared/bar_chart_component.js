(function() {
  "use strict";

  App.BarChartComponent = {
    initialize: function() {
      var charts = document.querySelectorAll("[data-bar-chart]");
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
      var orientation = container.dataset.chartOrientation || "vertical";
      var colors = container.dataset.chartColors ? JSON.parse(container.dataset.chartColors) : null;

      var isHorizontal = orientation === "horizontal";
      var backgroundColor = colors || "#6BA3D6";
      var borderColor = colors || "#6BA3D6";

      var ctx = canvas.getContext("2d");

      new Chart(ctx, {
        type: "bar",
        data: {
          labels: labels,
          datasets: [{
            data: values,
            backgroundColor: backgroundColor,
            borderColor: borderColor,
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
              }
            }
          },
          scales: {
            x: {
              grid: {
                display: !isHorizontal,
                color: "#e0e0e0"
              },
              ticks: {
                color: "#333",
                font: {
                  size: 15,
                  weight: 400
                }
              },
              border: {
                display: false
              }
            },
            y: {
              grid: {
                display: isHorizontal,
                color: "#e0e0e0"
              },
              ticks: {
                color: "#333",
                font: {
                  size: 15,
                  weight: 400
                }
              },
              border: {
                display: false
              },
              beginAtZero: true
            }
          }
        }
      });

      container.dataset.chartInitialized = "true";
    }
  };
}).call(this);
