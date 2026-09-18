# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/javascript/lib", under: "lib"
# intl-tel-input ships a UMD bundle, so it is vendored and re-exported as an ES module
pin "intl-tel-input", to: "lib/intl_tel_input.js"
pin "intl-tel-input/umd", to: "intl-tel-input--umd.js" # @25.12.2
pin "intl-tel-input/utils", to: "intl-tel-input--utils.js" # @25.12.2
