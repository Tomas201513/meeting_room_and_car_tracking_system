# Resource Scheduler - Package Installer

required_packages <- c(
  "shiny",
  "bslib",
  "toastui",
  "DT",
  "RSQLite",
  "shinyWidgets",
  "shinymanager",
  "colourpicker",
  "shinyjs"
)

# Installs package if not already available
install_if_missing <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    message(paste("Installing", pkg, "..."))
    install.packages(pkg)
  } else {
    message(paste(pkg, "is already installed"))
  }
}

invisible(lapply(required_packages, install_if_missing))

message("\nAll packages installed.")
message("Run the app with: shiny::runApp()")
message("\nDefault credentials:")
message("  Admin: admin / admin")
message("  User:  user / user")
