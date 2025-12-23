# Meeting Room Booking System - Global Configuration
# This file is loaded before ui.R and server.R

# ===== Required Packages =====
library(shiny)
library(bslib)
library(toastui)
library(DT)
library(RSQLite)
library(shinyWidgets)
library(shinymanager)

# ===== Authentication Credentials =====
credentials <- data.frame(
  user = c("admin", "user"),
  password = c("admin", "user"),
  start = c(NA, NA),
  expire = c(NA, NA),
  admin = c(TRUE, FALSE),
  comment = c("Administrator", "Regular User"),
  stringsAsFactors = FALSE
)

# ===== Database Initialization =====
init_db <- function() {
  con <- dbConnect(SQLite(), "scheduler.db")
  dbExecute(con, "PRAGMA foreign_keys = ON;")
  
  # rooms table
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS rooms (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      room_name TEXT NOT NULL UNIQUE,
      accomodate INTEGER,
      description TEXT,
      status INTEGER DEFAULT 1
    );
  ")
  
  # meeting_schedule table
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
  
  # car table
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS car (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      car_name TEXT NOT NULL,
      car_model TEXT NOT NULL,
      car_plate_no TEXT NOT NULL,
      accomodate TEXT NOT NULL,
      description TEXT,
      status INTEGER DEFAULT 1
    );
  ")
  
  # car_schedule table
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

# Initialize database on app start
init_db()

# ===== Database Helper Functions =====
db_conn <- function() {
  con <- dbConnect(SQLite(), "scheduler.db")
  dbExecute(con, "PRAGMA foreign_keys = ON;")
  con
}

# ---- Room Functions ----
get_rooms <- function() {
  con <- db_conn()
  on.exit(dbDisconnect(con))
  if (!dbExistsTable(con, "rooms")) return(data.frame())
  dbReadTable(con, "rooms")
}

add_room <- function(room_name, accomodate, description, status) {
  con <- db_conn()
  on.exit(dbDisconnect(con))
  dbExecute(con,
            "INSERT INTO rooms (room_name, accomodate, description, status)
     VALUES (?, ?, ?, ?)",
            params = list(room_name, accomodate, description, ifelse(isTRUE(status), 1, 0))
  )
}

delete_room <- function(id) {
  con <- db_conn()
  on.exit(dbDisconnect(con))
  dbExecute(con, "DELETE FROM rooms WHERE id = ?", params = list(id))
}

# ---- Meeting Functions ----
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

add_meeting <- function(room_id, start_dt, end_dt, organiser, purpose) {
  con <- db_conn()
  on.exit(dbDisconnect(con))
  dbExecute(con, "
    INSERT INTO meeting_schedule (room_id, start_datetime, end_datetime, organiser, meeting_purpose)
    VALUES (?, ?, ?, ?, ?)
  ", params = list(room_id, start_dt, end_dt, organiser, purpose))
}

delete_meeting <- function(id) {
  con <- db_conn()
  on.exit(dbDisconnect(con))
  dbExecute(con, "DELETE FROM meeting_schedule WHERE id = ?", params = list(id))
}















# ---- Car Functions ----
get_cars <- function() {
  con <- db_conn()
  on.exit(dbDisconnect(con))
  if (!dbExistsTable(con, "car")) return(data.frame())
  dbReadTable(con, "car")
}


add_car <- function(car_name, car_model, car_plate_no, accomodate, description, status) {
  con <- db_conn()
  on.exit(dbDisconnect(con))
  dbExecute(con,
            "INSERT INTO car (car_name, car_model, car_plate_no, accomodate, description, status)
     VALUES (?, ?, ?, ?, ?, ?)",
            params = list(car_name, car_model, car_plate_no, accomodate, description, ifelse(isTRUE(status), 1, 0))
  )
}


delete_car <- function(id) {
  con <- db_conn()
  on.exit(dbDisconnect(con))
  dbExecute(con, "DELETE FROM car WHERE id = ?", params = list(id))
}



# ---- Car Booking Functions ----
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


add_car_booking <- function(car_plate_no, start_dt, end_dt, passanger_name,
                            department, trip_purpose, no_of_passangers,
                            share, pickup_location, dropoff_location, comments) {
  con <- db_conn()
  on.exit(dbDisconnect(con))
  dbExecute(con, "
    INSERT INTO car_schedule (car_plate_no, start_datetime, end_datetime,
                              passanger_name, department, trip_purpose,
                              no_of_passangers, share, pickup_location,
                              dropoff_location, comments)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  ", params = list(car_plate_no, start_dt, end_dt, passanger_name,
                   department, trip_purpose, no_of_passangers,
                   ifelse(isTRUE(share), 1, 0), pickup_location,
                   dropoff_location, comments))
}

delete_car_booking <- function(id) {
  con <- db_conn()
  on.exit(dbDisconnect(con))
  dbExecute(con, "DELETE FROM car_schedule WHERE id = ?", params = list(id))
}
