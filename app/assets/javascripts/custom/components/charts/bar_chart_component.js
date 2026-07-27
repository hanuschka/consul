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

      App.ChartLoadingPlaceholder.markWhenRendered(chartConfig, container);

      new Chart(ctx, chartConfig);
      container.dataset.chartInitialized = "true";
    },

    getChartData: function(container) {
      const labels = JSON.parse(container.dataset.chartLabels || "[]");
      const values = JSON.parse(container.dataset.chartValues || "[]");
      const series = container.dataset.chartSeries ? JSON.parse(container.dataset.chartSeries) : null;
      const orientation = container.dataset.chartOrientation || "vertical";
      const colors = container.dataset.chartColors ? JSON.parse(container.dataset.chartColors) : null;
      const usePercentage = container.dataset.chartUsePercentage === "true";
      const showLabelsInBars = container.dataset.chartShowLabelsInBars === "true";
      const showLegend = container.dataset.chartShowLegend === "true";
      const stacked = container.dataset.chartStacked === "true";

      return {
        labels: labels,
        values: values,
        series: series,
        stacked: stacked,
        isHorizontal: orientation === "horizontal",
        backgroundColor: colors || "#6BA3D6",
        borderColor: colors || "#6BA3D6",
        usePercentage: usePercentage,
        showLabelsInBars: showLabelsInBars,
        showLegend: showLegend,
        maxValue: this.getMaxValue(values, series, stacked)
      };
    },

    getMaxValue: function(values, series, stacked) {
      if (!series) return Math.max.apply(null, values);

      const pointTotals = series[0].values.map(function(_, index) {
        const pointValues = series.map((entry) => entry.values[index]);

        if (stacked) {
          return pointValues.reduce((sum, value) => sum + value, 0);
        }

        return Math.max.apply(null, pointValues);
      });

      return Math.max.apply(null, pointTotals);
    },

    createLegendConfig: function(chartData) {
      if (chartData.series) {
        return {
          display: chartData.series.length > 1,
          position: "bottom",
          labels: {
            padding: 12,
            font: {
              size: 14
            },
            color: "#333",
            usePointStyle: true,
            pointStyle: "circle"
          }
        };
      }

      if (!chartData.showLegend) {
        return { display: false };
      }

      return {
        display: true,
        position: "bottom",
        labels: {
          padding: 12,
          font: {
            size: 14
          },
          color: "#333",
          usePointStyle: true,
          pointStyle: "circle",
          generateLabels: this.generateLegendLabels
        },
        onClick: this.handleLegendClick
      };
    },

    generateLegendLabels: function(chart) {
      const dataset = chart.data.datasets[0];

      return chart.data.labels.map((label, index) => {
        const color = Array.isArray(dataset.backgroundColor)
          ? dataset.backgroundColor[index]
          : dataset.backgroundColor;

        return {
          text: label,
          fillStyle: color,
          strokeStyle: color,
          lineWidth: 0,
          pointStyle: "circle",
          hidden: !chart.getDataVisibility(index),
          index: index
        };
      });
    },

    handleLegendClick: function(event, legendItem, legend) {
      legend.chart.toggleDataVisibility(legendItem.index);
      legend.chart.update();
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
            const formattedValue = chartData.usePercentage ? roundedValue + "%" : roundedValue;

            if (chartData.series) {
              return context.dataset.label + ": " + formattedValue;
            }

            return formattedValue;
          }
        }
      };
    },

    createDatasets: function(chartData) {
      const barThickness = chartData.isHorizontal ? 35 : 40;

      if (!chartData.series) {
        return [{
          data: chartData.values,
          backgroundColor: chartData.backgroundColor,
          borderColor: chartData.borderColor,
          borderWidth: 0,
          borderRadius: 4,
          barThickness: barThickness
        }];
      }

      return chartData.series.map(function(entry) {
        return {
          label: entry.label,
          data: entry.values,
          backgroundColor: entry.color,
          borderColor: entry.color,
          borderWidth: 0,
          borderRadius: 4,
          barThickness: barThickness
        };
      });
    },

    createChartConfig: function(chartData) {
      const valueAxisConfig = this.createValueAxisConfig(chartData);
      const labelAxisConfig = this.createLabelAxisConfig(chartData);

      if (chartData.stacked) {
        valueAxisConfig.stacked = true;
        labelAxisConfig.stacked = true;
      }

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
          datasets: this.createDatasets(chartData)
        },
        options: {
          indexAxis: chartData.isHorizontal ? "y" : "x",
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: this.createLegendConfig(chartData),
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
