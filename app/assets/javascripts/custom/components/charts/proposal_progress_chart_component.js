(function() {
  "use strict";

  App.ProposalProgressChartComponent = {
    PROGRESS_COLOR: "#004a83",
    SUCCESS_COLOR: "#ff7f0e",
    ACHIEVEMENT_COLOR: "#ff0000",
    GOAL_COLOR: "#005c92",
    FONT_SIZE: 14,
    Y_AXIS_HEADROOM: 1.1,

    initialize() {
      App.ChartInstances.destroyDetached();
      document.querySelectorAll(".js-proposal-progress-chart").forEach(this.initChart.bind(this));
    },

    initChart(container) {
      if (container.dataset.chartInitialized === "true") return;

      container.dataset.chartInitialized = "true";

      $.when(
        App.Ajax.get(container.dataset.proposalResourcesUrl),
        App.Ajax.get(container.dataset.proposalGraphUrl),
        App.Ajax.get(container.dataset.successfulProposalGraphUrl),
        App.Ajax.get(container.dataset.proposalAchievementsUrl)
      )
        .done(this.drawFromResponses.bind(this, container))
        .fail(this.showLoadError.bind(this, container));
    },

    showLoadError(container) {
      container.classList.add("-load-failed");
    },

    drawFromResponses(container, resources, progress, success, achievements) {
      if (!container.isConnected) return;

      this.draw(container, {
        goals: resources[0],
        progress: progress[0],
        success: success[0],
        achievements: achievements[0]
      });
    },

    draw(container, series) {
      const keys = this.sortedKeys(series);
      const goals = series.goals.map((goal) => ({ value: goal.required_supports, text: goal.title }));
      const chartConfig = {
        type: "line",
        data: {
          labels: keys.map((key) => this.formatLabel(container, key)),
          datasets: [
            this.progressDataset(container, keys, series),
            this.successDataset(container, keys, series)
          ]
        },
        options: this.chartOptions(container, keys, series, goals),
        plugins: [this.goalLinesPlugin(goals)]
      };

      App.ChartLoadingPlaceholder.markWhenRendered(chartConfig, container);

      new Chart(container.querySelector("canvas"), chartConfig);
    },

    sortedKeys(series) {
      const keys = new Set([
        ...Object.keys(series.progress),
        ...Object.keys(series.success),
        ...Object.keys(series.achievements)
      ]);

      return Array.from(keys).sort((first, second) => this.chronologicalRank(first) - this.chronologicalRank(second));
    },

    chronologicalRank(key) {
      const day = key.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/);
      const week = key.match(/^(\d{1,2})\/(\d{4})$/);
      const month = key.match(/^(\d{4})-(\d{1,2})$/);

      if (day) return Number(day[1]) * 10000 + Number(day[2]) * 100 + Number(day[3]);
      if (week) return Number(week[2]) * 100 + Number(week[1]);
      if (month) return Number(month[1]) * 100 + Number(month[2]);

      return 0;
    },

    progressDataset(container, keys, series) {
      const pointColors = keys.map((key) => {
        return this.hasKey(series.achievements, key) ? this.ACHIEVEMENT_COLOR : this.PROGRESS_COLOR;
      });

      return {
        label: container.dataset.proposalGraphProgressLabel,
        data: this.valuesFor(keys, series.progress),
        borderColor: this.PROGRESS_COLOR,
        backgroundColor: this.PROGRESS_COLOR,
        pointBackgroundColor: pointColors,
        pointBorderColor: pointColors,
        pointRadius: keys.map((key) => (this.hasKey(series.achievements, key) ? 5 : 2.5)),
        borderWidth: 2,
        tension: 0,
        spanGaps: true
      };
    },

    successDataset(container, keys, series) {
      return {
        label: container.dataset.proposalGraphSuccessLabel,
        data: this.valuesFor(keys, series.success),
        borderColor: this.SUCCESS_COLOR,
        backgroundColor: this.SUCCESS_COLOR,
        pointRadius: 2.5,
        borderWidth: 2,
        tension: 0,
        spanGaps: true
      };
    },

    chartOptions(container, keys, series, goals) {
      return {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          mode: "index",
          intersect: false
        },
        plugins: {
          legend: {
            position: "bottom",
            labels: {
              font: { size: this.FONT_SIZE }
            }
          },
          tooltip: {
            titleFont: { size: this.FONT_SIZE },
            bodyFont: { size: this.FONT_SIZE },
            callbacks: {
              title: (items) => this.tooltipTitle(container, keys, series.achievements, items[0].dataIndex)
            }
          }
        },
        scales: {
          x: {
            ticks: {
              autoSkip: true,
              maxTicksLimit: 13,
              maxRotation: 0,
              font: { size: this.FONT_SIZE }
            }
          },
          y: {
            beginAtZero: true,
            suggestedMax: this.yAxisMax(container, series, goals),
            ticks: {
              font: { size: this.FONT_SIZE }
            },
            title: {
              display: true,
              text: container.dataset.proposalGraphSupportsLabel,
              font: { size: this.FONT_SIZE }
            }
          }
        }
      };
    },

    yAxisMax(container, series, goals) {
      const highestValue = Math.max(
        0,
        ...Object.values(series.progress),
        ...Object.values(series.success),
        ...goals.map((goal) => goal.value)
      );

      if (highestValue === 0) return parseInt(container.dataset.proposalSuccess, 10);

      return Math.round(highestValue * this.Y_AXIS_HEADROOM);
    },

    tooltipTitle(container, keys, achievements, index) {
      const key = keys[index];
      const label = this.formatLabel(container, key);

      if (this.hasKey(achievements, key)) return label + ": " + achievements[key].title;

      return label;
    },

    goalLinesPlugin(goals) {
      return {
        id: "proposalGoalLines",
        afterDatasetsDraw: (chart) => this.drawGoalLines(chart, goals)
      };
    },

    drawGoalLines(chart, goals) {
      const context = chart.ctx;
      const area = chart.chartArea;

      context.save();
      context.strokeStyle = this.GOAL_COLOR;
      context.fillStyle = this.GOAL_COLOR;
      context.font = this.FONT_SIZE + "px " + Chart.defaults.font.family;
      context.textAlign = "right";
      context.lineWidth = 1;

      goals.forEach((goal) => {
        const y = chart.scales.y.getPixelForValue(goal.value);

        if (y < area.top || y > area.bottom) return;

        context.beginPath();
        context.moveTo(area.left, y);
        context.lineTo(area.right, y);
        context.stroke();
        context.fillText(goal.text, area.right - 4, y - 4);
      });

      context.restore();
    },

    valuesFor(keys, values) {
      return keys.map((key) => (this.hasKey(values, key) ? values[key] : null));
    },

    formatLabel(container, key) {
      const dayParts = key.match(/^\d{4}-(\d{1,2})-(\d{1,2})$/);

      if (container.dataset.proposalGraphGroupBy || !dayParts) return key;

      return dayParts[1] + "/" + dayParts[2];
    },

    hasKey(object, key) {
      return Object.prototype.hasOwnProperty.call(object, key);
    }
  };
}).call(this);
