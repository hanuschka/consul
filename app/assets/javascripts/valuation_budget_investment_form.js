(function() {
  "use strict";
  App.ValuationBudgetInvestmentForm = {

    showFeasibleFields: function() {
      $("#valuation_budget_investment_edit_form .unfeasible_fields").hide("down");
      $("#valuation_budget_investment_edit_form .feasible_fields").show();
    },

    showNotFeasibleFields: function() {
      $("#valuation_budget_investment_edit_form .feasible_fields").hide("down");
      $("#valuation_budget_investment_edit_form .unfeasible_fields").show();
    },

    hideAllFields: function() {
      $("#valuation_budget_investment_edit_form .feasible_fields").hide();
      $("#valuation_budget_investment_edit_form .unfeasible_fields").hide();
    },

    showFeasibilityFields: function() {
      var feasibility;
      feasibility = $("#valuation_budget_investment_edit_form input[type=radio][name='budget_investment[feasibility]']:checked").val();
      if (feasibility === "feasible") {
        App.ValuationBudgetInvestmentForm.showFeasibleFields();
      } else if (feasibility === "unfeasible") {
        App.ValuationBudgetInvestmentForm.showNotFeasibleFields();
      }
    },

    showFeasibilityFieldsOnChange: function() {
      $("#valuation_budget_investment_edit_form input[type=radio][name='budget_investment[feasibility]']").on("change", function() {
        App.ValuationBudgetInvestmentForm.hideAllFields();
        App.ValuationBudgetInvestmentForm.showFeasibilityFields();
      });
    },

    initialize: function() {
      App.ValuationBudgetInvestmentForm.hideAllFields();
      App.ValuationBudgetInvestmentForm.showFeasibilityFields();
      App.ValuationBudgetInvestmentForm.showFeasibilityFieldsOnChange();
    }
  };
}).call(this);
