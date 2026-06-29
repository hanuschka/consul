App.Studio.utils.urlParamsToFormData = function(serializedUrlParams) {
  const formData = new FormData()
  const searchParams = new URLSearchParams(serializedUrlParams);
  searchParams.forEach((value, key) => {
    formData.append(key, value)
  })

  return formData
}

App.Studio.utils.formElementToUrlObjectWithParams = function(form) {
  const url = new URL(`${form.action}`)
  const queryParamsObject = formElementToObject(form)
  url.search = objectToQueryString(queryParamsObject)

  return url
}

App.Studio.utils.formElementToUrlParams = function(form) {
  const formData = new FormData(form)
  formData.delete('_method')
  formData.delete('authenticity_token')

  return new URLSearchParams(formData).toString()
}
