(function() {
  "use strict";

  App.ChartInstances = {
    destroyDetached() {
      if (typeof Chart === "undefined") return;

      Object.values(Chart.instances).forEach((chart) => {
        if (!chart.canvas.isConnected) chart.destroy();
      });
    }
  };
}).call(this);
