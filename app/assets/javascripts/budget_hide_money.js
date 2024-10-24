(function() {
  "use strict";
  App.BudgetHideMoney = {
    initialize: function() {
      $("#budget_voting_style").on({
        change: function() {
          // if ($(this).val() === "approval") {
          if ($(this).val() === "approval" || $(this).val() === "distributed") { // custom
            $("#hide_money").removeClass("hide");
            $("#max_ballot_lines").removeClass("hide");
          } else {
            $("#budget_hide_money").prop("checked", false);
            $("#hide_money").addClass("hide");
            $("#max_ballot_lines").addClass("hide");
          }
        }
      });
    }
  };
}).call(this);
