# Resource Scheduler - Global Configuration & Database Functions

library(shiny)
library(bslib)
library(toastui)
library(DT)
library(RSQLite)
library(shinyWidgets)
library(shinymanager)
library(colourpicker)
library(shinyjs)

# Authentication credentials
credentials <- data.frame(
  user = c("admin", "user"),
  password = c("admin", "user"),
  start = c(NA, NA),
  expire = c(NA, NA),
  admin = c(TRUE, FALSE),
  comment = c("Administrator", "Regular User"),
  stringsAsFactors = FALSE
)

# Creates database tables if they don't exist
init_db <- function() {
  con <- dbConnect(SQLite(), "scheduler.db")
  dbExecute(con, "PRAGMA foreign_keys = ON;")
  
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS rooms (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      room_name TEXT NOT NULL UNIQUE,
      accomodate INTEGER,
      description TEXT,
      color TEXT DEFAULT '#4285F4',
      status INTEGER DEFAULT 1
    );
  ")
  
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS meeting_schedule (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      room_id INTEGER NOT NULL,
      start_datetime TEXT NOT NULL,
      end_datetime TEXT NOT NULL,
      organiser TEXT,
      meeting_purpose TEXT,
      FOREIGN KEY(room_id) REFERENCES rooms(id) ON DELETE CASCADE
    );
  ")
  
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS car (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      car_name TEXT NOT NULL,
      car_model TEXT NOT NULL,
      car_plate_no TEXT NOT NULL UNIQUE,
      accomodate TEXT NOT NULL,
      description TEXT,
      color TEXT DEFAULT '#0F9D58',
      status INTEGER DEFAULT 1
    );
  ")
  
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS car_schedule (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      car_plate_no TEXT NOT NULL,
      start_datetime TEXT NOT NULL,
      end_datetime TEXT NOT NULL,
      passanger_name TEXT NOT NULL,
      department TEXT NOT NULL,
      trip_purpose TEXT NOT NULL,
      no_of_passangers INTEGER NOT NULL,
      share INTEGER DEFAULT 1,
      pickup_location TEXT NOT NULL,
      dropoff_location TEXT NOT NULL,
      comments TEXT,
      FOREIGN KEY(car_plate_no) REFERENCES car(car_plate_no) ON DELETE CASCADE
    );
  ")
  
  dbDisconnect(con)
}

init_db()

# Returns a new database connection with foreign keys enabled
db_conn <- function() {
  con <- dbConnect(SQLite(), "scheduler.db")
  dbExecute(con, "PRAGMA foreign_keys = ON;")
  con
}

# ---------------------------------------------------------------------------
# Room Functions
# ---------------------------------------------------------------------------

# Returns all rooms from database
get_rooms <- function() {
  con <- db_conn()
  on.exit(dbDisconnect(con))
  if (!dbExistsTable(con, "rooms")) return(data.frame())
  dbReadTable(con, "rooms")
}

# Inserts a new room
add_room <- function(room_name, accomodate, description, color, status) {
  con <- db_conn()
  on.exit(dbDisconnect(con))
  dbExecute(con,
            "INSERT INTO rooms (room_name, accomodate, description, color, status)
     VALUES (?, ?, ?, ?, ?)",
            params = list(room_name, accomodate, description, color, ifelse(isTRUE(status), 1, 0))
  )
}

# Deletes a room by ID (cascades to meetings)
delete_room <- function(id) {
  con <- db_conn()
  on.exit(dbDisconnect(con))
  dbExecute(con, "DELETE FROM rooms WHERE id = ?", params = list(id))
}

# ---------------------------------------------------------------------------
# Meeting Functions
# ---------------------------------------------------------------------------

# Returns all meetings joined with room names
get_meetings_joined <- function() {
  con <- db_conn()
  on.exit(dbDisconnect(con))
  if (!dbExistsTable(con, "meeting_schedule")) return(data.frame())
  dbGetQuery(con, "
    SELECT m.id,
           r.room_name,
           m.start_datetime,
           m.end_datetime,
           m.organiser,
           m.meeting_purpose,
           m.room_id
    FROM meeting_schedule m
    JOIN rooms r ON r.id = m.room_id
    ORDER BY datetime(m.start_datetime) DESC
  ")
}

# Checks if a time slot overlaps with existing meetings for a room
meeting_overlaps <- function(room_id, start_dt, end_dt) {
  con <- db_conn()
  on.exit(dbDisconnect(con))
  count <- dbGetQuery(con, "
    SELECT COUNT(*) AS n
    FROM meeting_schedule
    WHERE room_id = ?
      AND datetime(?) < datetime(end_datetime)
      AND datetime(?) > datetime(start_datetime)
  ", params = list(room_id, start_dt, end_dt))$n
  count > 0
}

# Inserts a new meeting
add_meeting <- function(room_id, start_dt, end_dt, organiser, purpose) {
  con <- db_conn()
  on.exit(dbDisconnect(con))
  dbExecute(con, "
    INSERT INTO meeting_schedule (room_id, start_datetime, end_datetime, organiser, meeting_purpose)
    VALUES (?, ?, ?, ?, ?)
  ", params = list(room_id, start_dt, end_dt, organiser, purpose))
}

# Deletes a meeting by ID
delete_meeting <- function(id) {
  con <- db_conn()
  on.exit(dbDisconnect(con))
  dbExecute(con, "DELETE FROM meeting_schedule WHERE id = ?", params = list(id))
}

# ---------------------------------------------------------------------------
# Car Functions
# ---------------------------------------------------------------------------

# Returns all cars from database
get_cars <- function() {
  con <- db_conn()
  on.exit(dbDisconnect(con))
  if (!dbExistsTable(con, "car")) return(data.frame())
  dbReadTable(con, "car")
}

# Inserts a new car
add_car <- function(car_name, car_model, car_plate_no, accomodate, description, color, status) {
  con <- db_conn()
  on.exit(dbDisconnect(con))
  dbExecute(con,
            "INSERT INTO car (car_name, car_model, car_plate_no, accomodate, description, color, status)
     VALUES (?, ?, ?, ?, ?, ?, ?)",
            params = list(car_name, car_model, car_plate_no, accomodate, description, color, ifelse(isTRUE(status), 1, 0))
  )
}

# Deletes a car by ID (cascades to bookings)
delete_car <- function(id) {
  con <- db_conn()
  on.exit(dbDisconnect(con))
  dbExecute(con, "DELETE FROM car WHERE id = ?", params = list(id))
}

# ---------------------------------------------------------------------------
# Car Booking Functions
# ---------------------------------------------------------------------------

# Returns all car bookings joined with car details
get_car_schedules_joined <- function() {
  con <- db_conn()
  on.exit(dbDisconnect(con))
  if (!dbExistsTable(con, "car_schedule")) return(data.frame())
  dbGetQuery(con, "
    SELECT cs.id,
           c.car_name,
           c.car_plate_no,
           cs.start_datetime,
           cs.end_datetime,
           cs.passanger_name,
           cs.department,
           cs.trip_purpose,
           cs.no_of_passangers,
           cs.share,
           cs.pickup_location,
           cs.dropoff_location,
           cs.comments
    FROM car_schedule cs
    JOIN car c ON c.car_plate_no = cs.car_plate_no
    ORDER BY datetime(cs.start_datetime) DESC
  ")
}

# Checks if a time slot overlaps with existing bookings for a car
car_booking_overlaps <- function(car_plate_no, start_dt, end_dt) {
  con <- db_conn()
  on.exit(dbDisconnect(con))
  count <- dbGetQuery(con, "
    SELECT COUNT(*) AS n
    FROM car_schedule
    WHERE car_plate_no = ?
      AND datetime(?) < datetime(end_datetime)
      AND datetime(?) > datetime(start_datetime)
  ", params = list(car_plate_no, start_dt, end_dt))$n
  count > 0
}

# Inserts a new car booking
add_car_schedule <- function(car_plate_no, start_datetime, end_datetime, passanger_name,
                            department, trip_purpose, no_of_passangers,
                            share = TRUE, pickup_location, dropoff_location, comments) {
  con <- db_conn()
  on.exit(dbDisconnect(con))
  dbExecute(con, "
    INSERT INTO car_schedule (car_plate_no, start_datetime, end_datetime,
                              passanger_name, department, trip_purpose,
                              no_of_passangers, share, pickup_location,
                              dropoff_location, comments)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  ", params = list(car_plate_no, start_datetime, end_datetime, passanger_name,
                   department, trip_purpose, no_of_passangers,
                   ifelse(isTRUE(share), 1, 0), pickup_location,
                   dropoff_location, comments))
}

# Deletes a car booking by ID
delete_car_schedule <- function(id) {
  con <- db_conn()
  on.exit(dbDisconnect(con))
  dbExecute(con, "DELETE FROM car_schedule WHERE id = ?", params = list(id))
}
