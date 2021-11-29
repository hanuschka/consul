class DeficiencyReport::Status < ApplicationRecord
  AVAILABLE_ICONS = %w[ad address-book address-book address-card address-card adjust air-freshener align-center align-justify align-left align-right allergies ambulance american-sign-language-interpreting anchor angle-double-down angle-double-left angle-double-right angle-double-up angle-down angle-left angle-right angle-up angry angry ankh apple-alt archive archway arrow-alt-circle-down arrow-alt-circle-down arrow-alt-circle-left arrow-alt-circle-left arrow-alt-circle-right arrow-alt-circle-right arrow-alt-circle-up arrow-alt-circle-up arrow-circle-down arrow-circle-left arrow-circle-right arrow-circle-up arrow-down arrow-left arrow-right arrow-up arrows-alt arrows-alt-h arrows-alt-v assistive-listening-systems asterisk at atlas atom audio-description award baby baby-carriage backspace backward bacon bacteria bacterium bahai balance-scale balance-scale-left balance-scale-right ban band-aid barcode bars baseball-ball basketball-ball bath battery-empty battery-full battery-half battery-quarter battery-three-quarters bed beer bell bell bell-slash bell-slash bezier-curve bible bicycle biking binoculars biohazard birthday-cake blender blender-phone blind blog bold bolt bomb bone bong book book-dead book-medical book-open book-reader bookmark bookmark border-all border-none border-style bowling-ball box box-open box-tissue boxes braille brain bread-slice briefcase briefcase-medical broadcast-tower broom brush bug building building bullhorn bullseye burn bus bus-alt business-time calculator calendar calendar calendar-alt calendar-alt calendar-check calendar-check calendar-day calendar-minus calendar-minus calendar-plus calendar-plus calendar-times calendar-times calendar-week camera camera-retro campground candy-cane cannabis capsules car car-alt car-battery car-crash car-side caravan caret-down caret-left caret-right caret-square-down caret-square-down caret-square-left caret-square-left caret-square-right caret-square-right caret-square-up caret-square-up caret-up carrot cart-arrow-down cart-plus cash-register cat certificate chair chalkboard chalkboard-teacher charging-station chart-area chart-bar chart-bar chart-line chart-pie check check-circle check-circle check-double check-square check-square cheese chess chess-bishop chess-board chess-king chess-knight chess-pawn chess-queen chess-rook chevron-circle-down chevron-circle-left chevron-circle-right chevron-circle-up chevron-down chevron-left chevron-right chevron-up child church circle circle circle-notch city clinic-medical clipboard clipboard clipboard-check clipboard-list clock clock clone clone closed-captioning closed-captioning cloud cloud-download-alt cloud-meatball cloud-moon cloud-moon-rain cloud-rain cloud-showers-heavy cloud-sun cloud-sun-rain cloud-upload-alt cocktail code code-branch coffee cog cogs coins columns comment comment comment-alt comment-alt comment-dollar comment-dots comment-dots comment-medical comment-slash comments comments comments-dollar compact-disc compass compass compress compress-alt compress-arrows-alt concierge-bell cookie cookie-bite copy copy copyright copyright couch credit-card credit-card crop crop-alt cross crosshairs crow crown crutch cube cubes cut database deaf democrat desktop dharmachakra diagnoses dice dice-d20 dice-d6 dice-five dice-four dice-one dice-six dice-three dice-two digital-tachograph directions disease divide dizzy dizzy dna dog dollar-sign dolly dolly-flatbed donate door-closed door-open dot-circle dot-circle dove download drafting-compass dragon draw-polygon drum drum-steelpan drumstick-bite dumbbell dumpster dumpster-fire dungeon edit edit egg eject ellipsis-h ellipsis-v envelope envelope envelope-open envelope-open envelope-open-text envelope-square equals eraser ethernet euro-sign exchange-alt exclamation exclamation-circle exclamation-triangle expand expand-alt expand-arrows-alt external-link-alt external-link-square-alt eye eye eye-dropper eye-slash eye-slash fan fast-backward fast-forward faucet fax].map{ |x| [x] }

  translates :title, touch: true
  translates :description, touch: true
  include Globalizable

  has_many :deficiency_reports, foreign_key: :deficiency_report_status_id

  def self.create_default_objects
    return if DeficiencyReport::Status.count > 0
    DeficiencyReport::Status.create(
      title: 'Offen',
      color: 'red',
      icon: 'hourglass-start'
    )
    DeficiencyReport::Status.create(
      title: 'In Bearbeitung',
      color: 'orange',
      icon: 'hourglass-half'
    )
    DeficiencyReport::Status.create(
      title: 'Erledigt',
      color: 'green',
      icon: 'hourglass-end'
    )
  end

  def safe_to_destroy?
    !deficiency_reports.exists?
  end
end
