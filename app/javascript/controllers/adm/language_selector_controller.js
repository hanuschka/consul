import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  switch(event) {
    const url = new URL(window.location.href)

    url.searchParams.set("locale", event.target.value)
    window.location.assign(url.toString())
  }
}
