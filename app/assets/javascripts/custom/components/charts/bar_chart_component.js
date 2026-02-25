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

      const chartData = this.getChartData(container);
      this.adjustContainerHeight(container, chartData);

      const ctx = canvas.getContext("2d");
      const chartConfig = this.createChartConfig(chartData);

      new Chart(ctx, chartConfig);
      container.dataset.chartInitialized = "true";
    },

    getChartData: function(container) {
      const labels = JSON.parse(container.dataset.chartLabels || "[]");
      const values = JSON.parse(container.dataset.chartValues || "[]");
      const orientation = container.dataset.chartOrientation || "vertical";
      const colors = container.dataset.chartColors ? JSON.parse(container.dataset.chartColors) : null;
      const usePercentage = container.dataset.chartUsePercentage === "true";
      const showLabelsInBars = container.dataset.chartShowLabelsInBars === "true";

      return {
        labels: labels,
        values: values,
        isHorizontal: orientation === "horizontal",
        backgroundColor: colors || "#6BA3D6",
        borderColor: colors || "#6BA3D6",
        usePercentage: usePercentage,
        showLabelsInBars: showLabelsInBars,
        maxValue: Math.max.apply(null, values)
      };
    },

    createValueAxisConfig: function(chartData) {
      const config = {
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
        suggestedMax: chartData.maxValue
      };

      if (chartData.usePercentage) {
        config.min = 0;
        config.max = 100;
        config.suggestedMax = undefined;
        config.ticks.stepSize = undefined;
        config.ticks.callback = function(value) {
          if (Number.isInteger(value)) {
            return value + "%";
          }
          return null;
        };
      }

      return config;
    },

    createLabelAxisConfig: function(chartData) {
      return {
        grid: {
          display: false,
          color: "#e0e0e0"
        },
        ticks: {
          display: !chartData.showLabelsInBars,
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
    },

    createTooltipConfig: function(chartData) {
      return {
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
            const value = chartData.isHorizontal ? context.parsed.x : context.parsed.y;
            const roundedValue = Math.round(value);
            return chartData.usePercentage ? roundedValue + "%" : roundedValue;
          }
        }
      };
    },

    createChartConfig: function(chartData) {
      const valueAxisConfig = this.createValueAxisConfig(chartData);
      const labelAxisConfig = this.createLabelAxisConfig(chartData);

      const datalabelsConfig = chartData.showLabelsInBars
        ? {
            color: "#fff",
            font: {
              size: 12,
              weight: "bold"
            },
            anchor: "end",
            align: "start",
            offset: 4,
            formatter: (value, context) => {
              return context.chart.data.labels[context.dataIndex];
            }
          }
        : {
            display: false
          };

      return {
        type: "bar",
        plugins: [ChartDataLabels],
        data: {
          labels: chartData.labels,
          datasets: [{
            data: chartData.values,
            backgroundColor: chartData.backgroundColor,
            borderColor: chartData.borderColor,
            borderWidth: 0,
            borderRadius: 4,
            barThickness: chartData.isHorizontal ? 35 : 40
          }]
        },
        options: {
          indexAxis: chartData.isHorizontal ? "y" : "x",
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: {
              display: false
            },
            tooltip: this.createTooltipConfig(chartData),
            datalabels: datalabelsConfig
          },
          scales: {
            x: chartData.isHorizontal ? valueAxisConfig : labelAxisConfig,
            y: chartData.isHorizontal ? labelAxisConfig : valueAxisConfig
          }
        }
      };
    },

    adjustContainerHeight: function(container, chartData) {
      if (!chartData.isHorizontal) {
        return;
      }

      const barHeight = 35;
      const barSpacing = 12;
      const paddingTop = 10;
      const paddingBottom = 30;
      const calculatedHeight = (chartData.labels.length * (barHeight + barSpacing)) + paddingTop + paddingBottom;
      container.style.height = calculatedHeight + "px";
    }
  };
}).call(this);
