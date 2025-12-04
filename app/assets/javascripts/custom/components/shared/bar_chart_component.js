(function() {
  "use strict";

  App.BarChartComponent = {
    initialize: function() {
      const charts = document.querySelectorAll("[data-bar-chart]");
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

      const labels = JSON.parse(container.dataset.chartLabels || "[]");
      const values = JSON.parse(container.dataset.chartValues || "[]");
      const orientation = container.dataset.chartOrientation || "vertical";
      const colors = container.dataset.chartColors ? JSON.parse(container.dataset.chartColors) : null;
      const usePercentage = container.dataset.chartUsePercentage === "true";

      const isHorizontal = orientation === "horizontal";
      const backgroundColor = colors || "#6BA3D6";
      const borderColor = colors || "#6BA3D6";

      if (isHorizontal) {
        const barHeight = 35;
        const barSpacing = 12;
        const paddingTop = 10;
        const paddingBottom = 30;
        const calculatedHeight = (labels.length * (barHeight + barSpacing)) + paddingTop + paddingBottom;
        container.style.height = calculatedHeight + "px";
      }

      const maxValue = Math.max.apply(null, values);

      const valueAxisConfig = {
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
        suggestedMax: maxValue
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

      const labelAxisConfig = {
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

      const ctx = canvas.getContext("2d");

      const tooltipCallbacks = {
        label: function(context) {
          const value = isHorizontal ? context.parsed.x : context.parsed.y;
          const roundedValue = Math.round(value);
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
