# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "intl-tel-input", to: "https://ga.jspm.io/npm:intl-tel-input@25.12.2/build/js/intlTelInput.js"
pin "intl-tel-input/utils", to: "https://ga.jspm.io/npm:intl-tel-input@25.12.2/build/js/utils.js"
pin "trix"
pin "@rails/actiontext", to: "actiontext.esm.js"
