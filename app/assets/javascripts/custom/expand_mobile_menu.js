const toggleSubMenu = function(element) {

  const $menuElement = $(element).parent()
  const $arrow = $(element)

  if ( subMenuOpened($menuElement) ) {
    console.log('opening')
    $menuElement.children('ul:hidden').css('display', 'block') 
    $arrow.css('transform', 'rotate(90deg)')
  } else {
    console.log('closing')
    $menuElement.children('ul').css('display', 'none') 
    $arrow.css('transform', 'rotate(0deg)')
  }
}

const subMenuOpened = function(element) {
  if ( element.children('ul:hidden').length != 0 ) {
    return true
  } else {
    return false
  }
}


$(document).on("turbolinks:load",function(){
  $('#responsive-menu li.drop, #responsive-menu li.flyout').each( function() {

    //Add toggle arrow
    const toggleArrow  = document.createElement('div')
    $(toggleArrow).addClass('filter-toggle-arrow')
    toggleArrow.addEventListener('click', function(event) {
      toggleSubMenu(event.target);
    })
    this.prepend(toggleArrow)

    //Hide internal submenus
    $(this).children('ul').first().css('display', 'none')

  } )
})
