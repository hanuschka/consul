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

      var isHorizontal = orientation === "horizontal";

      var ctx = canvas.getContext("2d");

      new Chart(ctx, {
        type: "bar",
        data: {
          labels: labels,
          datasets: [{
            data: values,
            backgroundColor: "#6BA3D6",
            borderColor: "#6BA3D6",
            borderWidth: 0,
            borderRadius: 4,
            barThickness: isHorizontal ? 20 : 40
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
