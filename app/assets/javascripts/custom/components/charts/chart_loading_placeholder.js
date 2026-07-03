(function() {
  "use strict";

  App.ChartLoadingPlaceholder = {
    markWhenRendered: function(chartConfig, container) {
      chartConfig.plugins = chartConfig.plugins || [];

      chartConfig.plugins.push({
        id: "chartLoadingPlaceholder",
        afterRender: function(chart) {
          if (chart.width > 0 && chart.height > 0) {
            container.dataset.chartRendered = "true";
          }
        }
      });
    }
  };
}).call(this);
