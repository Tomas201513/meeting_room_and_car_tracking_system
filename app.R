# Resource Scheduler - Main Entry Point

source("global.R")
source("ui.R")
source("server.R")

shinyApp(
  ui = secure_app(ui),
  server = server
)
