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
      var usePercentage = container.dataset.chartUsePercentage === "true";

      var isHorizontal = orientation === "horizontal";
      var backgroundColor = colors || "#6BA3D6";
      var borderColor = colors || "#6BA3D6";

      if (isHorizontal) {
        var barHeight = 35;
        var barSpacing = 12;
        var paddingTop = 10;
        var paddingBottom = 30;
        var calculatedHeight = (labels.length * (barHeight + barSpacing)) + paddingTop + paddingBottom;
        container.style.height = calculatedHeight + "px";
      }

      var maxValue = Math.max.apply(null, values);

      var valueAxisConfig = {
        grid: {
          display: true,
          color: "#e0e0e0"
        },
        ticks: {
          color: "#333",
          font: {
            size: 15,
            weight: 400
          },
          stepSize: 1,
          callback: function(value) {
            if (Number.isInteger(value)) {
              return value;
            }
            return null;
          }
        },
        border: {
          display: false
        },
        beginAtZero: true,
        suggestedMax: maxValue < 5 ? 5 : undefined
      };

      if (usePercentage) {
        valueAxisConfig.min = 0;
        valueAxisConfig.max = 100;
        valueAxisConfig.suggestedMax = undefined;
        valueAxisConfig.ticks.stepSize = undefined;
        valueAxisConfig.ticks.callback = function(value) {
          if (Number.isInteger(value)) {
            return value + "%";
          }
          return null;
        };
      }

      var labelAxisConfig = {
        grid: {
          display: false,
          color: "#e0e0e0"
        },
        ticks: {
          color: "#333",
          font: {
            size: 15,
            weight: 400
          },
          autoSkip: false
        },
        border: {
          display: false
        }
      };

      var ctx = canvas.getContext("2d");

      var tooltipCallbacks = {
        label: function(context) {
          var value = isHorizontal ? context.parsed.x : context.parsed.y;
          var roundedValue = Math.round(value);
          return usePercentage ? roundedValue + "%" : roundedValue;
        }
      };

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
              },
              callbacks: tooltipCallbacks
            }
          },
          scales: {
            x: isHorizontal ? valueAxisConfig : labelAxisConfig,
            y: isHorizontal ? labelAxisConfig : valueAxisConfig
          }
        }
      });

      container.dataset.chartInitialized = "true";
    }
  };
}).call(this);
