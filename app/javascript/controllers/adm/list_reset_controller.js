import { Controller } from "@hotwired/stimulus"
import { forgetAllListStates } from "../../utils/adm_list_state"

export default class extends Controller {
  reset(event) {
    const link = event.target.closest("a[href]")
    if (!link || link.getAttribute("href") === "#") return

    forgetAllListStates()
  }
}
