import { Controller } from "@hotwired/stimulus"

// Submits the form whenever a control changes, so a "live" filter bar
// needs no explicit submit button. Attach to the <form> and delegate
// the change event: data-action="change->shared--auto-submit-form#submit".
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
