# Active Storage's default routes include an unauthenticated
# POST /rails/active_storage/direct_uploads endpoint that this application does
# not use. `config.active_storage.draw_routes = false` (config/application.rb)
# is only applied in an `after_initialize` hook, which can run after the route
# set has already been loaded, so the flag is also set here to make sure the
# engine routes are never drawn. The routes the application actually needs are
# drawn explicitly in config/routes.rb.
ActiveStorage.draw_routes = false
